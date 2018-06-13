class ManageIQ::Providers::Amazon::CloudManager::EventTargetParser
  attr_reader :ems_event

  # @param ems_event [EmsEvent] EmsEvent object
  def initialize(ems_event)
    @ems_event = ems_event
  end

  # Parses all targets that are present in the EmsEvent given in the initializer
  #
  # @return [Array] Array of ManagerRefresh::Target objects
  def parse
    parse_ems_event_targets(ems_event)
  end

  private

  # Parses list of ManagerRefresh::Target out of the given EmsEvent
  #
  # @param event [EmsEvent] EmsEvent object
  # @return [Array] Array of ManagerRefresh::Target objects
  def parse_ems_event_targets(event)
    target_collection = ManagerRefresh::TargetCollection.new(:manager => event.ext_management_system, :event => event)

    case event.full_data["event_source"]
    when :cloud_watch_api
      collect_cloudwatch_api_references!(target_collection,
                                         event.full_data.fetch_path("detail", "requestParameters") || {})
      collect_cloudwatch_api_references!(target_collection,
                                         event.full_data.fetch_path("detail", "responseElements") || {})
    when :cloud_watch_ec2
      collect_cloudwatch_ec2_references!(target_collection, event.full_data)
    when :cloud_watch_ec2_ebs_snapshot
      collect_cloudwatch_ec2_ebs_snapshot_references!(target_collection, event.full_data)
    when :config
      collect_config_references!(target_collection, event.full_data)
    end

    target_collection.targets
  end

  def parsed_targets(target_collection = {})
    target_collection.select { |_target_class, references| references[:manager_ref].present? }
  end

  def add_target(target_collection, association, ref)
    target_collection.add_target(:association => association, :manager_ref => {:ems_ref => ref}) unless ref.blank?
  end

  def add_name_target(target_collection, association, ref)
    target_collection.add_target(:association => association, :manager_ref => {:name => ref}) unless ref.blank?
  end

  def collect_cloudwatch_ec2_references!(target_collection, event_data)
    instance_id = event_data.fetch_path("detail", "instance-id")
    add_target(target_collection, :vms, instance_id) if instance_id
  end

  def collect_cloudwatch_ec2_ebs_snapshot_references!(target_collection, event_data)
    if (snapshot_id = event_data.fetch_path('detail', 'snapshot_id'))
      add_target(target_collection, :cloud_volume_snapshots, snapshot_id.split('/').last)
    end
  end

  def collect_config_references!(target_collection, event_data)
    resource_type = event_data.fetch_path("configurationItem", "resourceType")
    resource_id   = event_data.fetch_path("configurationItem", "resourceId")
    target_class  = case resource_type
                    when "AWS::EC2::Instance"
                      :vms
                    when "AWS::EC2::SecurityGroup"
                      :security_groups
                    when "AWS::EC2::Volume"
                      :cloud_volumes
                    when "AWS::EC2::NetworkInterface"
                      :network_ports
                    when "AWS::EC2::VPC"
                      :cloud_networks
                    when "AWS::EC2::Subnet"
                      :cloud_subnets
                    when "AWS::EC2::EIP"
                      :floating_ips
                    when "AWS::CloudFormation::Stack"
                      :orchestration_stacks
                    end

    add_target(target_collection, target_class, resource_id) if target_class && resource_id
  end

  def collect_cloudwatch_api_references!(target_collection, event_data, depth = 0)
    # Check a reasonable depth, so this can't fail with max stack size
    raise "Depth 20 reached when scanning EmsEvent for Targets" if depth > 20

    # Cloud
    add_target(target_collection, :vms, event_data["instanceId"]) if event_data["instanceId"]
    add_target(target_collection, :miq_templates, event_data["imageId"]) if event_data["imageId"]
    add_name_target(target_collection, :key_pairs, event_data["keyName"]) if event_data["keyName"]
    add_target(target_collection, :orchestration_stacks, event_data["stackId"]) if event_data["stackId"]
    add_target(target_collection, :orchestration_stacks, event_data["stackName"]) if event_data["stackName"]
    # Network
    add_target(target_collection, :cloud_networks, event_data["vpcId"]) if event_data["vpcId"]
    add_target(target_collection, :cloud_networks, event_data.fetch_path("vpc", "vpcId")) if event_data.fetch_path("vpc", "vpcId")
    if event_data.fetch_path("EnableVpcClassicLinkDnsSupportRequest", "VpcId")
      add_target(target_collection, :cloud_networks, event_data.fetch_path("EnableVpcClassicLinkDnsSupportRequest", "VpcId"))
    end
    add_target(target_collection, :cloud_subnets, event_data["subnetId"]) if event_data["subnetId"]
    add_target(target_collection, :network_ports, event_data["networkInterfaceId"]) if event_data["networkInterfaceId"]
    add_target(target_collection, :security_groups, event_data["groupId"]) if event_data["groupId"]
    add_target(target_collection, :floating_ips, event_data["allocationId"]) if event_data["allocationId"]
    add_target(target_collection, :load_balancers, event_data["loadBalancerName"]) if event_data["loadBalancerName"]
    # Block Storage
    add_target(target_collection, :cloud_volumes, event_data["volumeId"]) if event_data["volumeId"]
    add_target(target_collection, :cloud_volume_snapshots, event_data["snapshotId"]) if event_data["snapshotId"]

    # TODO(lsmola) how to handle tagging? Tagging affects e.g. a name of any resource, but contains only a generic
    # resourceID
    # "requestParameters"=>
    #   {"resourcesSet"=>{"items"=>[{"resourceId"=>"vol-07ad036724e3175a5"}]},
    #    "tagSet"=>{"items"=>[{"key"=>"Name", "value"=>"ladas_volue_2"}]}},
    # I think we can parse the resource id, so guess where it belongs.
    # TODO(lsmola) RegisterImage, by creating image from a volume snapshot, should we track the block device
    # mapping and refresh also snapshot?

    # Collect nested references
    collect_cloudwatch_api_references!(target_collection, event_data["networkInterface"], depth + 1) if event_data["networkInterface"]

    (event_data.fetch_path("groupSet", "items") || []).each do |x|
      collect_cloudwatch_api_references!(target_collection, x, depth + 1)
    end
    (event_data.fetch_path("instancesSet", "items") || []).each do |x|
      collect_cloudwatch_api_references!(target_collection, x, depth + 1)
    end
    (event_data.fetch_path("instances") || []).each do |x|
      collect_cloudwatch_api_references!(target_collection, x, depth + 1)
    end
    (event_data.fetch_path("networkInterfaceSet", "items") || []).each do |x|
      collect_cloudwatch_api_references!(target_collection, x, depth + 1)
    end
  end
end
