class ManageIQ::Providers::Amazon::Inventory::Collector::TargetCollection < ManageIQ::Providers::Amazon::Inventory::Collector
  def initialize(_ems, _options, _target)
    super
    parse_targets!
    infer_related_ems_refs!
  end

  def instances
    hash_collection.new(
      aws_ec2.instances(:filters => [{:name => 'instance-id', :values => instances_refs.to_a}])
    )
  end

  def private_images
    hash_collection.new(
      aws_ec2.client.describe_images(:filters => [{:name => 'image-id', :values => private_images_refs.to_a}]).images
    )
  end

  def stacks
    # TODO(lsmola) we can filter only one stack, so that means too many requests, lets try to figure out why
    # CLoudFormations API doesn't support a standard filter
    result = stacks_refs.to_a.map do |stack_ref|
      begin
        aws_cloud_formation.client.describe_stacks(:stack_name => stack_ref)[:stacks]
      rescue Aws::CloudFormation::Errors::ValidationError => _e
        # A missing stack throws and exception like this, we want to ignore it and just don't list it
      end
    end.flatten.compact

    hash_collection.new(result)
  end

  def cloud_networks
    hash_collection.new(
      aws_ec2.client.describe_vpcs(:filters => [{:name => 'vpc-id', :values => cloud_networks_refs.to_a}]).vpcs
    )
  end

  def cloud_subnets
    hash_collection.new(
      aws_ec2.client.describe_subnets(:filters => [{:name => 'subnet-id', :values => cloud_subnets_refs.to_a}]).subnets
    )
  end

  def security_groups
    hash_collection.new(
      aws_ec2.security_groups(:filters => [{:name => 'group-id', :values => security_groups_refs.to_a}])
    )
  end

  def network_ports
    hash_collection.new(aws_ec2.client.describe_network_interfaces(
      :filters => [{:name => 'network-interface-id', :values => network_ports_refs.to_a}]
    ).network_interfaces)
  end

  def load_balancers
    return [] if load_balancers_refs.blank?

    result = []
    load_balancers_refs.to_a.each do |load_balancers_ref|
      begin
        result += aws_elb.client.describe_load_balancers(
          :load_balancer_names => [load_balancers_ref]
        ).load_balancer_descriptions
      rescue ::Aws::ElasticLoadBalancing::Errors::LoadBalancerNotFound => _e
        # TODO(lsmola) maybe it will be faster to fetch all LBs and filter them?
        # Ignore LB that was not found, it will be deleted from our DB
      end
    end

    hash_collection.new(result)
  end

  def floating_ips
    hash_collection.new(
      aws_ec2.client.describe_addresses(:filters => [{:name => 'allocation-id', :values => floating_ips_refs.to_a}]).addresses
    )
  end

  def cloud_volumes
    hash_collection.new(
      aws_ec2.client.describe_volumes(:filters => [{:name => 'volume-id', :values => cloud_volumes_refs.to_a}]).volumes
    )
  end

  def cloud_volume_snapshots
    hash_collection.new(
      aws_ec2.client.describe_snapshots(
        :filters => [{:name => 'snapshot-id', :values => cloud_volume_snapshots_refs.to_a}]
      ).snapshots
    )
  end

  def cloud_object_store_containers
    # hash_collection.new(aws_s3.client.list_buckets.buckets)
    []
  end

  def cloud_object_store_objects
    # hash_collection.new([])
    []
  end

  # Nested API calls, we want all of them for our filtered list of LBs and Stacks
  def stack_resources(stack_name)
    begin
      stack_resources = aws_cloud_formation.client.list_stack_resources(:stack_name => stack_name).try(:stack_resource_summaries)
    rescue Aws::CloudFormation::Errors::ValidationError => _e
      # When Stack was deleted we want to return empty list of resources
    end

    hash_collection.new(stack_resources || [])
  end

  def health_check_members(load_balancer_name)
    hash_collection.new(aws_elb.client.describe_instance_health(
      :load_balancer_name => load_balancer_name
    ).instance_states)
  end

  def stack_template(stack_name)
    aws_cloud_formation.client.get_template(:stack_name => stack_name).template_body
  rescue Aws::CloudFormation::Errors::ValidationError => _e
    # When Stack was deleted we want to return empty string for template
    ""
  end

  private

  def parse_targets!
    target.targets.each do |t|
      if t.kind_of?(::EmsEvent)
        parse_parse_ems_event_target!(t)
      elsif t.kind_of?(::Vm)
        parse_vm_target!(t)
      end
    end
  end

  def parse_parse_ems_event_target!(t)
    collect_references!(t.full_data.fetch_path("detail", "requestParameters") || {})
    collect_references!(t.full_data.fetch_path("detail", "responseElements") || {})

    instance_id = t.full_data.fetch_path("detail", "instance-id")
    instances_refs << instance_id if instance_id
  end

  def collect_references!(hash)
    instances_refs << hash["instanceId"] if hash["instanceId"]
    private_images_refs << hash["imageId"] if hash["imageId"]
    key_pairs_refs << hash["keyName"] if hash["keyName"]
    stacks_refs << hash["stackId"] if hash["stackId"]
    stacks_refs << hash["stackName"] if hash["stackName"]
    cloud_networks_refs << hash["vpcId"] if hash["vpcId"]
    cloud_subnets_refs << hash["subnetId"] if hash["subnetId"]
    network_ports_refs << hash["networkInterfaceId"] if hash["networkInterfaceId"]
    security_groups_refs << hash["groupId"] if hash["groupId"]
    floating_ips_refs << hash["allocationId"] if hash["allocationId"]
    load_balancers_refs << hash["loadBalancerName"] if hash["loadBalancerName"]
    cloud_volumes_refs << hash["volumeId"] if hash["volumeId"]
    cloud_volume_snapshots_refs << hash["snapshotId"] if hash["snapshotId"]

    # TODO(lsmola) how to handle tagging? Tagging affects e.g. a name of any resource, but contains only a generic
    # resourceID
    # "requestParameters"=>
    #   {"resourcesSet"=>{"items"=>[{"resourceId"=>"vol-07ad036724e3175a5"}]},
    #    "tagSet"=>{"items"=>[{"key"=>"Name", "value"=>"ladas_volue_2"}]}},
    # I think we can parse the resource id, so guess where it belongs.
    # TODO(lsmola) RegisterImage, by creating image from a volume snapshot, should we track the block device
    # mapping and refresh also snapshot?

    collect_references!(hash["networkInterface"]) if hash["networkInterface"]

    (hash.fetch_path("groupSet", "items") || []).each { |x| collect_references!(x) }
    (hash.fetch_path("instancesSet", "items") || []).each { |x| collect_references!(x) }
    (hash.fetch_path("instances") || []).each { |x| collect_references!(x) }
    (hash.fetch_path("networkInterfaceSet", "items") || []).each { |x| collect_references!(x) }
  end

  def parse_vm_target!(t)
    instances_refs << t.ems_ref if t.ems_ref
  end

  def infer_related_ems_refs!
    # We have a list of instances_refs collected from events. Now we want to look into our DB and API, and collect
    # ems_refs of every related object. Now this is not very nice fro ma design point of view, but we really want
    # to see changes in VM's associated objects, so the VM view is always consistent and have fresh data. The partial
    # reason for this is, that AWS doesn't send all the objects state change,
    changed_vms = ems.vms.where(:ems_ref => instances_refs.to_a).includes(:key_pairs, :network_ports, :floating_ips,
                                                                          :orchestration_stack)
    changed_vms.each do |vm|
      stack      = vm.orchestration_stack
      all_stacks = ([stack] + (stack.try(:ancestors) || [])).compact
      stacks_refs.merge all_stacks.collect(&:ems_ref).compact
      key_pairs_refs.merge vm.key_pairs.collect(&:name).compact
      network_ports_refs.merge vm.network_ports.collect(&:ems_ref).compact
      floating_ips_refs.merge vm.floating_ips.collect(&:ems_ref).compact
    end
  end
end
