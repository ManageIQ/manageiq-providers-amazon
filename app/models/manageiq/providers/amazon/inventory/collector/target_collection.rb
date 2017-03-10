class ManageIQ::Providers::Amazon::Inventory::Collector::TargetCollection < ManageIQ::Providers::Amazon::Inventory::Collector
  def initialize(_manager, _target)
    super
    parse_targets!
    infer_related_ems_refs!

    target.manager_refs_by_association_reset
  end

  def references(collection)
    target.manager_refs_by_association.try(:[], collection).try(:[], :ems_ref).try(:to_a) || []
  end

  def instances
    hash_collection.new(
      aws_ec2.instances(:filters => [{:name => 'instance-id', :values => references(:vms)}])
    )
  end

  def private_images
    hash_collection.new(
      aws_ec2.client.describe_images(:filters => [{:name => 'image-id', :values => references(:miq_templates)}]).images
    )
  end

  def stacks
    # TODO(lsmola) we can filter only one stack, so that means too many requests, lets try to figure out why
    # CLoudFormations API doesn't support a standard filter
    result = references(:orchestrations_stacks).map do |stack_ref|
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
      aws_ec2.client.describe_vpcs(:filters => [{:name => 'vpc-id', :values => references(:cloud_networks)}]).vpcs
    )
  end

  def cloud_subnets
    hash_collection.new(
      aws_ec2.client.describe_subnets(:filters => [{:name => 'subnet-id', :values => references(:cloud_subnets)}]).subnets
    )
  end

  def security_groups
    hash_collection.new(
      aws_ec2.security_groups(:filters => [{:name => 'group-id', :values => references(:security_groups).to_a}])
    )
  end

  def network_ports
    hash_collection.new(aws_ec2.client.describe_network_interfaces(
      :filters => [{:name => 'network-interface-id', :values => references(:network_ports).to_a}]
    ).network_interfaces)
  end

  def load_balancers
    return [] if references(:load_balancers).blank?

    result = []
    references(:load_balancers).each do |load_balancers_ref|
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
      aws_ec2.client.describe_addresses(:filters => [{:name => 'allocation-id', :values => references(:floating_ips)}]).addresses
    )
  end

  def cloud_volumes
    hash_collection.new(
      aws_ec2.client.describe_volumes(:filters => [{:name => 'volume-id', :values => references(:cloud_volumes)}]).volumes
    )
  end

  def cloud_volume_snapshots
    hash_collection.new(
      aws_ec2.client.describe_snapshots(
        :filters => [{:name => 'snapshot-id', :values => references(:cloud_volumes_snapshots)}]
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
      case t
      when Vm
        parse_vm_target!(t)
      end
    end
  end

  def parse_vm_target!(t)
    target.add_target(:association => :vms, :manager_ref => {:ems_ref => t.ems_ref}) if t.ems_ref
  end

  def infer_related_ems_refs!
    # We have a list of instances_refs collected from events. Now we want to look into our DB and API, and collect
    # ems_refs of every related object. Now this is not very nice fro ma design point of view, but we really want
    # to see changes in VM's associated objects, so the VM view is always consistent and have fresh data. The partial
    # reason for this is, that AWS doesn't send all the objects state change,
    changed_vms = manager.vms.where(:ems_ref => references(:vms)).includes(:key_pairs, :network_ports, :floating_ips,
                                                                           :orchestration_stack)
    changed_vms.each do |vm|
      stack      = vm.orchestration_stack
      all_stacks = ([stack] + (stack.try(:ancestors) || [])).compact

      all_stacks.collect(&:ems_ref).compact.each do |ems_ref|
        target.add_target(:association => :orchestration_stacks, :manager_ref => {:ems_ref => ems_ref})
      end

      vm.key_pairs.collect(&:name).compact.each do |ems_ref|
        target.add_target(:association => :key_pairs, :manager_ref => {:ems_ref => ems_ref})
      end

      vm.network_ports.collect(&:ems_ref).compact.each do |ems_ref|
        target.add_target(:association => :network_ports, :manager_ref => {:ems_ref => ems_ref})
      end

      vm.floating_ips.collect(&:ems_ref).compact.each do |ems_ref|
        target.add_target(:association => :floating_ips, :manager_ref => {:ems_ref => ems_ref})
      end
    end
  end
end
