class ManageIQ::Providers::Amazon::CloudManager::EventTargetParser
  attr_reader :ems_event

  # @param ems_event [EmsEvent] EmsEvent object
  def initialize(ems_event)
    @ems_event = ems_event
  end

  # Parses all targets that are present in the EmsEvent given in the initialize
  def parse
    parse_ems_event_targets(ems_event)
  end

  private

  def parse_ems_event_targets(event)
    available_targets = init_available_targets

    case event.full_data["event_source"]
    when :cloud_watch_api
      collect_cloudwatch_api_references!(available_targets,
                                         event.full_data.fetch_path("detail", "requestParameters") || {})
      collect_cloudwatch_api_references!(available_targets,
                                         event.full_data.fetch_path("detail", "responseElements") || {})
    when :cloud_watch_ec2
      collect_cloudwatch_ec2_references!(available_targets, event.full_data)
    when :config
      collect_config_references!(available_targets, event.full_data)
    end

    parsed_targets(available_targets)
  end

  def init_available_targets
    available_target_classes = [
      # Cloud
      Vm,
      MiqTemplate,
      ManageIQ::Providers::CloudManager::AuthKeyPair,
      OrchestrationStack,
      # Network
      CloudNetwork,
      CloudSubnet,
      NetworkPort,
      SecurityGroup,
      FloatingIp,
      # Block Storage(EBS)
      CloudVolume,
      CloudVolumeSnapshot,
    ]

    available_target_classes.each_with_object({}) do |class_name, obj|
      obj[class_name.to_s] = {:manager_ref => Set.new}
    end
  end

  def parsed_targets(available_targets = {})
    available_targets.select { |_target_class, references| references[:manager_ref].present? }
  end

  def add_reference!(available_targets, target, ref)
    available_targets[target.to_s][:manager_ref] << {:ems_ref => ref}
  end

  def collect_cloudwatch_ec2_references!(available_targets, event_data)
    instance_id = event_data.fetch_path("detail", "instance-id")
    add_reference!(available_targets, Vm, instance_id) if instance_id
  end

  def collect_config_references!(available_targets, event_data)
    resource_type = event_data.fetch_path("configurationItem", "resourceType")
    resource_id   = event_data.fetch_path("configurationItem", "resourceId")
    target_class  = case resource_type
                    when "AWS::EC2::Instance"
                      Vm
                    when "AWS::EC2::SecurityGroup"
                      SecurityGroup
                    when "AWS::EC2::Volume"
                      CloudVolume
                    when "AWS::EC2::NetworkInterface"
                      NetworkPort
                    when "AWS::EC2::VPC"
                      CloudNetwork
                    when "AWS::EC2::Subnet"
                      CloudSubnet
                    when "AWS::EC2::EIP"
                      FloatingIp
                    end

    add_reference!(available_targets, target_class, resource_id) if target_class && resource_id
  end

  def collect_cloudwatch_api_references!(available_targets, event_data, depth = 0)
    # Check a reasonable depth, so this can't fail with max stack size
    raise "Depth 20 reached when scanning EmsEvent for Targets" if depth > 20

    # Cloud
    add_reference!(available_targets, Vm, event_data["instanceId"]) if event_data["instanceId"]
    add_reference!(available_targets, MiqTemplate, event_data["imageId"]) if event_data["imageId"]
    add_reference!(available_targets, ManageIQ::Providers::CloudManager::AuthKeyPair, event_data["keyName"]) if event_data["keyName"]
    add_reference!(available_targets, OrchestrationStack, event_data["stackId"]) if event_data["stackId"]
    add_reference!(available_targets, OrchestrationStack, event_data["stackName"]) if event_data["stackName"]
    # Network
    add_reference!(available_targets, CloudNetwork, event_data["vpcId"]) if event_data["vpcId"]
    add_reference!(available_targets, CloudSubnet, event_data["subnetId"]) if event_data["subnetId"]
    add_reference!(available_targets, NetworkPort, event_data["networkInterfaceId"]) if event_data["networkInterfaceId"]
    add_reference!(available_targets, SecurityGroup, event_data["groupId"]) if event_data["groupId"]
    add_reference!(available_targets, FloatingIp, event_data["allocationId"]) if event_data["allocationId"]
    add_reference!(available_targets, LoadBalancer, event_data["loadBalancerName"]) if event_data["loadBalancerName"]
    # Block Storage
    add_reference!(available_targets, CloudVolume, event_data["volumeId"]) if event_data["volumeId"]
    add_reference!(available_targets, CloudVolumeSnapshot, event_data["snapshotId"]) if event_data["snapshotId"]

    # TODO(lsmola) how to handle tagging? Tagging affects e.g. a name of any resource, but contains only a generic
    # resourceID
    # "requestParameters"=>
    #   {"resourcesSet"=>{"items"=>[{"resourceId"=>"vol-07ad036724e3175a5"}]},
    #    "tagSet"=>{"items"=>[{"key"=>"Name", "value"=>"ladas_volue_2"}]}},
    # I think we can parse the resource id, so guess where it belongs.
    # TODO(lsmola) RegisterImage, by creating image from a volume snapshot, should we track the block device
    # mapping and refresh also snapshot?

    # Collect nested references
    collect_cloudwatch_api_references!(available_targets, event_data["networkInterface"], depth + 1) if event_data["networkInterface"]

    (event_data.fetch_path("groupSet", "items") || []).each do |x|
      collect_cloudwatch_api_references!(available_targets, x, depth + 1)
    end
    (event_data.fetch_path("instancesSet", "items") || []).each do |x|
      collect_cloudwatch_api_references!(available_targets, x, depth + 1)
    end
    (event_data.fetch_path("instances") || []).each do |x|
      collect_cloudwatch_api_references!(available_targets, x, depth + 1)
    end
    (event_data.fetch_path("networkInterfaceSet", "items") || []).each do |x|
      collect_cloudwatch_api_references!(available_targets, x, depth + 1)
    end
  end
end
