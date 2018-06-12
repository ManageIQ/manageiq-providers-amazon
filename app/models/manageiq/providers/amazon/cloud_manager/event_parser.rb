module ManageIQ::Providers::Amazon::CloudManager::EventParser
  def self.parse_config_event!(event, event_hash)
    event_hash[:message]                   = event["configurationItemDiff"]
    event_hash[:timestamp]                 = event["notificationCreationTime"]
    event_hash[:vm_ems_ref]                = parse_vm_ref(event)
    event_hash[:availability_zone_ems_ref] = parse_availability_zone_ref(event)
  end

  def self.parse_cloud_watch_api_event!(event, event_hash)
    event_hash[:message]                   = "request: #{event.fetch_path("detail", "requestParameters")}, "\
                                             "response: #{event.fetch_path("detail", "responseElements")}"
    event_hash[:timestamp]                 = event["time"]
    # TODO(lsmola) so Event can be tied to more Vms, we will need to change the modeling
    event_hash[:vm_ems_ref]                = event.fetch_path("detail", "responseElements", "instancesSet", "items")
                                               .try(:first).try(:[], "instanceId")
    event_hash[:availability_zone_ems_ref] = nil # Can't get it, needs to go through VM
  end

  def self.parse_cloud_watch_ec2_event!(event, event_hash)
    event_hash[:message]                   = event["detail"]
    event_hash[:timestamp]                 = event["time"]
    event_hash[:vm_ems_ref]                = event.fetch_path("detail", "instance-id")
    event_hash[:availability_zone_ems_ref] = nil # Can't get it, needs to go through VM
  end

  def self.parse_cloud_watch_ec2_ebs_snapshot_event!(event, event_hash)
    event_hash[:message]                   = event['detail']
    event_hash[:timestamp]                 = event['time']
    event_hash[:vm_ems_ref]                = nil
    event_hash[:availability_zone_ems_ref] = nil
  end

  def self.parse_cloud_watch_alarm_event!(event, event_hash)
    event_hash[:message]                   = event["AlarmName"]
    event_hash[:timestamp]                 = event["StateChangeTime"]
    event_hash[:vm_ems_ref]                = nil # Can't get it
    event_hash[:availability_zone_ems_ref] = nil # Can't get it
  end

  def self.event_to_hash(event, ems_id)
    event_hash = {
      :event_type => event["eventType"],
      :source     => "AMAZON",
      :full_data  => event,
      :ems_id     => ems_id
    }

    parse_method_name = "parse_#{event["event_source"]}_event!"
    if singleton_class.method_defined?(parse_method_name)
      send(parse_method_name, event, event_hash)
    else
      raise "Unsupported event source #{event["event_source"]}"
    end

    log_header = "ems_id: [#{ems_id}] " unless ems_id.nil?
    _log.debug("#{log_header}event: [#{event[:message]}]")

    event_hash
  end

  def self.parse_vm_ref(event)
    resource_type = event["configurationItem"]["resourceType"]
    # other ways to find the VM?
    event.fetch_path("configurationItem", "resourceId") if resource_type == "AWS::EC2::Instance"
  end

  def self.parse_availability_zone_ref(event)
    event.fetch_path("configurationItem", "availabilityZone")
  end
end
