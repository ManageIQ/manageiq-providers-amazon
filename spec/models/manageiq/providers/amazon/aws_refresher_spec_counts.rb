module AwsRefresherSpecCounts
  extend ActiveSupport::Concern

  def expected_ext_management_systems_count
    ::Settings.prototype.amazon.s3 ? 4 : 3
  end

  def base_inventory_counts
    {
      :auth_private_key              => 0,
      :availability_zone             => 0,
      :cloud_network                 => 0,
      :cloud_subnet                  => 0,
      :cloud_volume                  => 0,
      :cloud_volume_backup           => 0,
      :cloud_volume_snapshot         => 0,
      :custom_attribute              => 0,
      :disk                          => 0,
      :ext_management_system         => expected_ext_management_systems_count,
      :firewall_rule                 => 0,
      :flavor                        => 0,
      :floating_ip                   => 0,
      :guest_device                  => 0,
      :hardware                      => 0,
      :miq_template                  => 0,
      :network                       => 0,
      :network_port                  => 0,
      :network_router                => 0,
      :operating_system              => 0,
      :orchestration_stack           => 0,
      :orchestration_stack_output    => 0,
      :orchestration_stack_parameter => 0,
      :orchestration_stack_resource  => 0,
      :orchestration_template        => 0,
      :security_group                => 0,
      :service_instances             => 0,
      :service_offerings             => 0,
      :service_parameters_sets       => 0,
      :snapshot                      => 0,
      :system_service                => 0,
      :vm                            => 0,
      :vm_or_template                => 0,
      :tagging                       => 0
    }
  end

  def assert_counts(expected_table_counts)
    expected_counts = base_inventory_counts.merge(expected_table_counts)
    assert_table_counts(expected_counts)
    assert_ems(expected_counts)
  end

  def table_counts_from_api
    all_instance_hashes        = instances
    instance_hashes            = all_instance_hashes.select { |x| x["state"]["name"] != "terminated" }
    image_hashes               = private_images + shared_images + public_images
    # Only new refresh can collect a referenced images
    image_hashes += referenced_images(instance_hashes, image_hashes) if options.inventory_object_refresh
    instances_count            = instance_hashes.size
    images_count               = image_hashes.size
    instances_and_images_count = instances_count + images_count

    vms_tags = instance_hashes.map { |x| x["tags"] }.flatten.compact
    images_tags = image_hashes.map { |x| x["tags"] }.flatten.compact
    # Custom attributes of all Vms and Images
    custom_attributes_count = (vms_tags + images_tags).size

    vms_mappings = ContainerLabelTagMapping.where(:labeled_resource_type => nil).or(
      ContainerLabelTagMapping.where(:labeled_resource_type => "Vm")
    ).pluck(:label_name)
    # Correct count of mapped tags for Vms
    vms_tags_count = vms_tags.select { |x| vms_mappings.include?(x["key"]) && x["value"].present? }.count

    images_mappings = ContainerLabelTagMapping.where(:labeled_resource_type => nil).or(
      ContainerLabelTagMapping.where(:labeled_resource_type => "Image")
    ).pluck(:label_name)
    # Correct count of mapped tags for Images
    images_tags_count = images_tags.select { |x| images_mappings.include?(x["key"]) && x["value"].present? }.count

    # Networks for all Vms is a list of private and public addresses of a 1 interface of a Vm
    networks_count             = instance_hashes.map { |x| [x['public_ip_address'], x['private_ip_address']] }.flatten.compact.size

    indexed_flavors        = Flavor.all.index_by(&:name)
    ephemeral_disk_count   = instance_hashes.map { |x| indexed_flavors[x["instance_type"]].ephemeral_disk_count }.sum
    attached_volumes_count = instance_hashes.map { |x| x["block_device_mappings"] }.flatten.size
    # Total number of disks is ephemeral_disk_count driven by a Flavor + number of attached volumes
    disks_count            = ephemeral_disk_count + attached_volumes_count

    security_group_hashes = security_groups.all
    security_groups_count = security_group_hashes.count

    load_balancers_size = load_balancers.size

    # Total number of firewall rules is inferred from security groups
    firewall_rules_count  = security_group_hashes.map do |rule|
      (
        rule["ip_permissions"].map { |perm| perm["user_id_group_pairs"] } +
        rule["ip_permissions"].map { |perm| perm["ip_ranges"] } +
        rule["ip_permissions"].map { |perm| perm["ipv_6_ranges"] } +
        rule["ip_permissions_egress"].map { |perm| perm["user_id_group_pairs"] } +
        rule["ip_permissions_egress"].map { |perm| perm["ip_ranges"] } +
        rule["ip_permissions_egress"].map { |perm| perm["ipv_6_ranges"] }
      )
    end.flatten.size

    # TODO(lsmola) we don't filter out terminated instances for getting network_ports from EC2 classic instances, fix it
    # then we can use instance_hashes instead of all_instance_hashes here.
    ec2_classic_instance_hashes = all_instance_hashes.select { |x| x['network_interfaces'].blank? }
    network_port_hashes         = network_ports.all
    # Network ports count consists of VPC ENIs + ec2_classic_instances
    network_ports_count         = network_port_hashes.size + ec2_classic_instance_hashes.size + load_balancers_size

    network_routers_count = network_routers.all.size

    floating_ip_hashes = floating_ips.all
    # VPC floating IPs are taken from floating_ips and network_ports + EC2 classic floating ips are taken from
    # floating_ips and instances. FloatingIp model then holds all AWS public and Elastic IPs.
    floating_ips_refs  = Set.new
    floating_ips_refs.merge(
      network_port_hashes.map do |network_port|
        network_port["private_ip_addresses"].map do |private_address|
          private_address.fetch_path('association', 'allocation_id') ||
            private_address.fetch_path('association', 'public_ip')
        end
      end.flatten.compact
    )
    floating_ips_refs.merge(
      floating_ip_hashes.map { |floating_ip| floating_ip['allocation_id'] || floating_ip['public_ip'] }.compact
    )
    floating_ips_refs.merge(
      ec2_classic_instance_hashes.map { |instance| instance['public_ip_address'] }.compact
    )

    floating_ips_count = floating_ips_refs.size + load_balancers_size

    orchestration_stack_hashes = stacks.all
    orchestration_stacks_count = orchestration_stack_hashes.size

    orchestration_stack_parameters_count = orchestration_stack_hashes.map { |x| x["parameters"] }.flatten.compact.size
    orchestration_stack_outputs_count    = orchestration_stack_hashes.map { |x| x["outputs"] }.flatten.compact.size
    orchestration_stack_resources_count  = stacks_resources.size

    orchestration_templates_count = orchestration_stacks_count - (OrchestrationStack.pluck(:orchestration_template_id).count -
      OrchestrationStack.pluck(:orchestration_template_id).uniq.count)

    base_inventory_counts.merge(
      :auth_private_key              => key_pairs.size,
      :availability_zone             => availability_zones.size,
      :cloud_network                 => cloud_networks.size,
      :cloud_subnet                  => cloud_subnets.size,
      :cloud_volume                  => cloud_volumes.size,
      :cloud_volume_snapshot         => cloud_volume_snapshots.size,
      :custom_attribute              => custom_attributes_count,
      :disk                          => disks_count,
      :firewall_rule                 => firewall_rules_count,
      :flavor                        => 132,
      :floating_ip                   => floating_ips_count,
      :hardware                      => instances_and_images_count,
      :miq_template                  => images_count,
      :network                       => networks_count,
      :network_port                  => network_ports_count,
      :network_router                => network_routers_count,
      :operating_system              => instances_and_images_count,
      :orchestration_stack           => orchestration_stacks_count,
      :orchestration_stack_output    => orchestration_stack_outputs_count,
      :orchestration_stack_parameter => orchestration_stack_parameters_count,
      :orchestration_stack_resource  => orchestration_stack_resources_count,
      :orchestration_template        => orchestration_templates_count,
      :security_group                => security_groups_count,
      :service_instances             => 0,
      :service_offerings             => 0,
      :service_parameters_sets       => 0,
      :tagging                       => vms_tags_count + images_tags_count,
      :vm                            => instances_count,
      :vm_or_template                => instances_and_images_count
    )
  end

  def assert_table_counts(expected_table_counts)
    actual = {
      :auth_private_key              => AuthPrivateKey.count,
      :cloud_volume                  => CloudVolume.count,
      :cloud_volume_backup           => CloudVolumeBackup.count,
      :cloud_volume_snapshot         => CloudVolumeSnapshot.count,
      :ext_management_system         => ExtManagementSystem.count,
      :flavor                        => Flavor.count,
      :availability_zone             => AvailabilityZone.count,
      :vm_or_template                => VmOrTemplate.count,
      :vm                            => Vm.count,
      :miq_template                  => MiqTemplate.count,
      :disk                          => Disk.count,
      :guest_device                  => GuestDevice.count,
      :hardware                      => Hardware.count,
      :network                       => Network.count,
      :operating_system              => OperatingSystem.count,
      :snapshot                      => Snapshot.count,
      :system_service                => SystemService.count,
      :orchestration_template        => OrchestrationTemplate.count,
      :orchestration_stack           => OrchestrationStack.count,
      :orchestration_stack_parameter => OrchestrationStackParameter.count,
      :orchestration_stack_output    => OrchestrationStackOutput.count,
      :orchestration_stack_resource  => OrchestrationStackResource.count,
      :security_group                => SecurityGroup.count,
      :service_instances             => ServiceInstance.count,
      :service_offerings             => ServiceOffering.count,
      :service_parameters_sets       => ServiceParametersSet.count,
      :firewall_rule                 => FirewallRule.count,
      :network_port                  => NetworkPort.count,
      :cloud_network                 => CloudNetwork.count,
      :floating_ip                   => FloatingIp.count,
      :network_router                => NetworkRouter.count,
      :cloud_subnet                  => CloudSubnet.count,
      :custom_attribute              => CustomAttribute.count,
      :tagging                       => Tagging.count,
    }
    expect(actual).to eq expected_table_counts
  end

  def assert_ems(expected_table_counts)
    expect(@ems).to have_attributes(
      :api_version => nil, # TODO: Should be 3.0
      :uid_ems     => nil
    )
    expect(@ems.flavors.size).to eql(expected_table_counts[:flavor])
    expect(@ems.availability_zones.size).to eql(expected_table_counts[:availability_zone])
    expect(@ems.vms_and_templates.size).to eql(expected_table_counts[:vm_or_template])
    expect(@ems.security_groups.size).to eql(expected_table_counts[:security_group])
    expect(@ems.network_ports.size).to eql(expected_table_counts[:network_port])
    expect(@ems.cloud_networks.size).to eql(expected_table_counts[:cloud_network])
    expect(@ems.floating_ips.size).to eql(expected_table_counts[:floating_ip])
    expect(@ems.network_routers.size).to eql(expected_table_counts[:network_router])
    expect(@ems.cloud_subnets.size).to eql(expected_table_counts[:cloud_subnet])
    expect(@ems.miq_templates.size).to eq(expected_table_counts[:miq_template])

    expect(@ems.orchestration_stacks.size).to eql(expected_table_counts[:orchestration_stack])
  end

  private

  def manager
    @ems
  end

  def aws_ec2
    @aws_ec2 ||= manager.connect
  end

  def aws_cloud_formation
    @aws_cloud_formation ||= manager.connect(:service => :CloudFormation)
  end

  def aws_elb
    @aws_elb ||= manager.connect(:service => :ElasticLoadBalancing)
  end

  def aws_s3
    @aws_s3 ||= manager.connect(:service => :S3)
  end

  def options
    @options ||= Settings.ems_refresh[manager.class.ems_type]
  end

  def hash_collection
    ::ManageIQ::Providers::Amazon::Inventory::HashCollection
  end

  # helpers for getting records fro mthe API
  def instances
    hash_collection.new(aws_ec2.instances).all
  end

  def flavors
    ManageIQ::Providers::Amazon::InstanceTypes.all
  end

  def availability_zones
    hash_collection.new(aws_ec2.client.describe_availability_zones[:availability_zones])
  end

  def key_pairs
    hash_collection.new(aws_ec2.client.describe_key_pairs[:key_pairs])
  end

  def private_images
    return [] unless options.get_private_images

    hash_collection.new(
      aws_ec2.client.describe_images(:owners  => [:self],
                                     :filters => [{:name   => "image-type",
                                                   :values => ["machine"]}]).images
    ).all
  end

  def shared_images
    return [] unless options.get_shared_images

    hash_collection.new(
      aws_ec2.client.describe_images(:executable_users => [:self],
                                     :filters          => [{:name   => "image-type",
                                                            :values => ["machine"]}]).images
    ).all
  end

  def public_images
    return [] unless options.get_public_images

    hash_collection.new(
      aws_ec2.client.describe_images(:executable_users => [:all],
                                     :filters          => options.to_hash[:public_images_filters]).images
    ).all
  end

  def referenced_images(instance_hashes, image_hashes)
    refs = extra_image_references(instance_hashes, image_hashes)

    hash_collection.new(
      aws_ec2.client.describe_images(:filters => [{:name => 'image-id', :values => refs}]).images
    ).all
  end

  def stacks
    hash_collection.new(aws_cloud_formation.client.describe_stacks[:stacks])
  end

  def stacks_resources
    resources = []
    stacks.each do |stack|
      resources << hash_collection.new(aws_cloud_formation.client.list_stack_resources(
        :stack_name => stack["stack_name"]
      ).try(:stack_resource_summaries)).all.select { |res| res['physical_resource_id'] }
    end
    resources.flatten.compact
  end

  def stack_template(stack_name)
    aws_cloud_formation.client.get_template(:stack_name => stack_name).template_body
  end

  def cloud_networks
    hash_collection.new(aws_ec2.client.describe_vpcs[:vpcs])
  end

  def cloud_subnets
    hash_collection.new(aws_ec2.client.describe_subnets[:subnets])
  end

  def security_groups
    hash_collection.new(aws_ec2.security_groups)
  end

  def network_ports
    hash_collection.new(aws_ec2.client.describe_network_interfaces.network_interfaces)
  end

  def network_routers
    hash_collection.new(aws_ec2.route_tables)
  end

  def load_balancers
    hash_collection.new(aws_elb.client.describe_load_balancers.load_balancer_descriptions)
  end

  def health_check_members(load_balancer_name)
    hash_collection.new(aws_elb.client.describe_instance_health(
      :load_balancer_name => load_balancer_name
    ).instance_states)
  end

  def floating_ips
    hash_collection.new(aws_ec2.client.describe_addresses.addresses)
  end

  def cloud_volumes
    hash_collection.new(aws_ec2.client.describe_volumes[:volumes])
  end

  def cloud_volume_snapshots
    hash_collection.new(aws_ec2.client.describe_snapshots(:owner_ids => [:self])[:snapshots])
  end

  def extra_image_references(instance_hashes, image_hashes)
    # The references to images that are not collected by private_images, shared_images or public_images but that are
    # referenced by instances. Which can be caused e.g. by using a public_image while not collecting it under
    # public_images

    db_image_refs        = Set.new(manager.miq_templates.pluck(:ems_ref))
    instances_image_refs = Set.new(instance_hashes.map { |x| x["image_id"] })
    api_images_refs      = Set.new(image_hashes.map { |x| x["image_id"] })

    ((db_image_refs + instances_image_refs) - api_images_refs).to_a.sort
  end
end
