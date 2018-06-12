#
# Uses the AWS Config or CloudWatch service to monitor for events.
#
# AWS Config or CloudWatch events are collected in an SNS Topic.  Each appliance uses a unique
# SQS queue subscribed to the AWS Config topic.  If the appliance-specific queue
# doesn't exist, this event monitor will create the queue and subscribe the
# queue to the AWS Config topic.

#
class ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Stream
  class ProviderUnreachable < ManageIQ::Providers::BaseManager::EventCatcher::Runner::TemporaryFailure
  end

  #
  # Creates an event monitor
  #
  # @param [ManageIQ::Providers::Amazon::CloudManager] ems
  # @param [String] sns_aws_config_topic_name
  AWS_CONFIG_TOPIC = "AWSConfig_topic".freeze
  def initialize(ems, sns_aws_config_topic_name = AWS_CONFIG_TOPIC)
    @ems          = ems
    @topic_name   = sns_aws_config_topic_name
    @stop_polling = false
    @before_poll  = nil
  end

  #
  # Stop capturing events
  #
  def stop
    @stop_polling = true
  end

  def before_poll(&block)
    @before_poll = block
  end

  #
  # Collect events off the appliance-specific queue and return the events as a
  # batch to the caller.
  #
  # :yield: array of Amazon events as hashes
  #
  def poll
    @ems.with_provider_connection(:service => :SQS) do |sqs|
      queue_poller = Aws::SQS::QueuePoller.new(
        find_or_create_queue,
        :client            => sqs.client,
        :wait_time_seconds => 20,
        :before_request    => @before_poll
      )
      begin
        queue_poller.poll do |sqs_message|
          $aws_log.debug("#{log_header} received message #{sqs_message}")
          throw :stop_polling if @stop_polling
          event = parse_event(sqs_message)
          yield event if event
        end
      rescue Aws::SQS::Errors::ServiceError => exception
        raise ProviderUnreachable, exception.message
      end
    end
  end

  private

  # @return [String] is a queue_url
  def find_or_create_queue
    queue_url = sqs_get_queue_url(queue_name)
    subscribe_topic_to_queue(sns_topic, queue_url) unless queue_subscribed_to_topic?(queue_url, sns_topic)
    add_policy_to_queue(queue_url, sns_topic.arn) unless queue_has_policy?(queue_url, sns_topic.arn)
    queue_url
  rescue Aws::SQS::Errors::NonExistentQueue
    $aws_log.info("#{log_header} Amazon SQS Queue #{queue_name} does not exist; creating queue")
    queue_url = sqs_create_queue(queue_name)
    subscribe_topic_to_queue(sns_topic, queue_url)
    add_policy_to_queue(queue_url, sns_topic.arn)
    $aws_log.info("#{log_header} Created Amazon SQS Queue #{queue_name} and subscribed to AWSConfig_topic")
    queue_url
  rescue Aws::SQS::Errors::ServiceError => exception
    raise ProviderUnreachable, exception.message
  end

  def queue_has_policy?(queue_url, topic_arn)
    policy_attribute = 'Policy'
    policy = @ems.with_provider_connection(:service => :SQS) do |sqs|
      sqs.client.get_queue_attributes(
        :queue_url       => queue_url,
        :attribute_names => [policy_attribute]
      ).attributes[policy_attribute]
    end

    policy == queue_policy(queue_url_to_arn(queue_url), topic_arn)
  end

  def queue_subscribed_to_topic?(queue_url, topic)
    queue_arn = queue_url_to_arn(queue_url)
    topic.subscriptions.any? { |subscription| subscription.attributes['Endpoint'] == queue_arn }
  end

  def sqs_create_queue(queue_name)
    @ems.with_provider_connection(:service => :SQS) do |sqs|
      sqs.client.create_queue(:queue_name => queue_name).queue_url
    end
  end

  def sqs_get_queue_url(queue_name)
    $aws_log.debug("#{log_header} Looking for Amazon SQS Queue #{queue_name} ...")
    @ems.with_provider_connection(:service => :SQS) do |sqs|
      sqs.client.get_queue_url(:queue_name => queue_name).queue_url
    end
  end

  # @return [Aws::SNS::Topic] the found topic
  # @raise [ProviderUnreachable] in case the topic is not found
  def sns_topic
    @ems.with_provider_connection(:service => :SNS) do |sns|
      get_topic(sns) || create_topic(sns)
    end
  end

  def get_topic(sns)
    sns.topics.detect { |t| t.arn.split(/:/)[-1] == @topic_name }
  end

  def create_topic(sns)
    topic = sns.create_topic(:name => @topic_name)
    $aws_log.info("Created SNS topic #{@topic_name}")
    topic
  rescue Aws::SNS::Errors::ServiceError => err
    raise ProviderUnreachable, "Cannot create SNS topic #{@topic_name}, #{err.class.name}, Message=#{err.message}"
  end

  # @param [Aws::SNS::Topic] topic
  def subscribe_topic_to_queue(topic, queue_url)
    queue_arn = queue_url_to_arn(queue_url)
    $aws_log.info("#{log_header} Subscribing Queue #{queue_url} to #{topic.arn}")
    subscription = topic.subscribe(:protocol => 'sqs', :endpoint => queue_arn)
    raise ProviderUnreachable, "Can't subscribe to #{queue_arn}" unless subscription.arn.present?
  end

  def add_policy_to_queue(queue_url, topic_arn)
    queue_arn = queue_url_to_arn(queue_url)
    policy    = queue_policy(queue_arn, topic_arn)

    @ems.with_provider_connection(:service => :SQS) do |sqs|
      sqs.client.set_queue_attributes(
        :queue_url  => queue_url,
        :attributes => {'Policy' => policy}
      )
    end
  end

  def queue_url_to_arn(queue_url)
    @queue_url_to_arn ||= {}
    @queue_url_to_arn[queue_url] ||= begin
      arn_attribute = "QueueArn"
      @ems.with_provider_connection(:service => :SQS) do |sqs|
        sqs.client.get_queue_attributes(
          :queue_url       => queue_url,
          :attribute_names => [arn_attribute]
        ).attributes[arn_attribute]
      end
    end
  end

  # @param [Aws::SQS::Types::Message] message
  def parse_event(message)
    event = JSON.parse(JSON.parse(message.body)['Message'])

    if event["messageType"] == "ConfigurationItemChangeNotification"
      # Aws Config Events
      event["eventType"]    = parse_event_type(event)
      event["event_source"] = :config

    elsif event.fetch_path("detail", "eventType") == "AwsApiCall"
      # CloudWatch with CloudTrail for API requests Events
      event["eventType"]    = "AWS_API_CALL_" + event.fetch_path("detail", "eventName")
      event["event_source"] = :cloud_watch_api

    elsif event["detail-type"] == "EC2 Instance State-change Notification"
      # CloudWatch EC2 Events
      state                 = "_#{event.fetch_path("detail", "state")}" if event.fetch_path("detail", "state")
      event["eventType"]    = "#{event["detail-type"].tr(" ", "_").tr("-", "_")}#{state}"
      event["event_source"] = :cloud_watch_ec2

    elsif event['detail-type'] == 'EBS Snapshot Notification'
      event['eventType']    = event['detail-type'].gsub(/[\s-]/, '_')
      event['event_source'] = :cloud_watch_ec2_ebs_snapshot

    elsif event["AlarmName"]
      # CloudWatch Alarm
      event["eventType"]    = "AWS_ALARM_#{event["AlarmName"]}"
      event["event_source"] = :cloud_watch_alarm

    else
      # Not recognized event, ignoring...
      $log.debug("#{log_header} Parsed event from SNS Message not recognized #{event}")
      return
    end

    $log.info("#{log_header} Found SNS Message with message type #{event["eventType"]} coming from #{event[:event_source]}")

    event["messageId"] = message.message_id
    $log.info("#{log_header} Parsed event from SNS Message #{event["eventType"]} coming from #{event[:event_source]}")
    event
  rescue JSON::ParserError => err
    $log.error("#{log_header} JSON::ParserError parsing '#{message.body}' - #{err.message}")
    nil
  end

  def parse_event_type(event)
    event_type_prefix = event.fetch_path("configurationItem", "resourceType")
    change_type       = event.fetch_path("configurationItemDiff", "changeType")

    if event_type_prefix.end_with?("::Instance")
      suffix   = change_type if change_type == "CREATE"
      suffix ||= parse_instance_state_change(event)
    else
      suffix = change_type
    end

    # e.g., AWS_EC2_Instance_STARTED
    "#{event_type_prefix}_#{suffix}".gsub("::", "_")
  end

  def parse_instance_state_change(event)
    change_type = event["configurationItemDiff"]["changeType"]
    return change_type if change_type == "CREATE"

    state_changed = event.fetch_path("configurationItemDiff", "changedProperties", "Configuration.State.Name")
    state_changed ? state_changed["updatedValue"] : change_type
  end

  def log_header
    @log_header ||= "MIQ(#{self.class.name}#)"
  end

  def queue_name
    @queue_name ||= "manageiq-awsconfig-queue-#{@ems.guid}"
  end

  def queue_policy(queue_arn, topic_arn)
    <<EOT
{
  "Version": "2012-10-17",
  "Id": "#{queue_arn}/SQSDefaultPolicy",
  "Statement": [
    {
      "Sid": "#{Digest::MD5.hexdigest(queue_arn)}",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "SQS:SendMessage",
      "Resource": "#{queue_arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "#{topic_arn}"
        }
      }
    }
  ]
}
EOT
  end
end
