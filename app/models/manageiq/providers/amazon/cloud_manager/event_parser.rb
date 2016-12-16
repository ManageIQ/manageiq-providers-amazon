module ManageIQ::Providers::Amazon::CloudManager::EventParser
  # these have their own EmsEvent classes in automate
  INSTANCE_EVENTS = %w(
    AWS_EC2_Instance_CREATE
    AWS_EC2_Instance_UPDATE
    AWS_EC2_Instance_DELETE
    AWS_EC2_Instance_running
    AWS_EC2_Instance_shutting-down
    AWS_EC2_Instance_stopped
  ).to_set.freeze

  def self.map_event_type(aws_event_type)
    if INSTANCE_EVENTS.include?(aws_event_type)
      aws_event_type
    else
      'ConfigurationItemChangeNotification'
    end
  end

  def self.format_message(event)
    changed_properties = event.fetch_path("configurationItemDiff", "changedProperties")
    if changed_properties.present?
      "#{event['eventType']}: #{changed_properties}"
    else
      "#{event['eventType']}"
    end
  end

  def self.event_to_hash(event, ems_id)
    log_header = "ems_id: [#{ems_id}] " unless ems_id.nil?

    _log.debug("#{log_header}event: [#{event["configurationItem"]["resourceType"]} - " \
               "#{event["configurationItem"]["resourceId"]}]")

    event_hash = {
      :event_type => map_event_type(event["eventType"]),
      :source     => "AMAZON",
      :message    => format_message(event),
      :timestamp  => event["notificationCreationTime"],
      :full_data  => event,
      :ems_id     => ems_id
    }

    event_hash[:vm_ems_ref]                = parse_vm_ref(event)
    event_hash[:availability_zone_ems_ref] = parse_availability_zone_ref(event)
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
