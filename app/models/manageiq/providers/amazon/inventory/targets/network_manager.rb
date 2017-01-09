class ManageIQ::Providers::Amazon::Inventory::Targets::NetworkManager < ManageIQ::Providers::Amazon::Inventory::Targets
  def initialize_inventory_collections
    add_inventory_collections(
      %i(cloud_subnet_network_ports network_ports floating_ips cloud_subnets cloud_networks security_groups
         firewall_rules load_balancers load_balancer_pools load_balancer_pool_members load_balancer_pool_member_pools
         load_balancer_listeners load_balancer_listener_pools load_balancer_health_checks
         load_balancer_health_check_members))

    add_inventory_collections(%i(vms orchestration_stack availability_zones),
                              :parent   => ems.parent_manager,
                              :strategy => :local_db_cache_all)
  end

  def cloud_networks
    HashCollection.new(aws_ec2.client.describe_vpcs[:vpcs])
  end

  def cloud_subnets
    HashCollection.new(aws_ec2.client.describe_subnets[:subnets])
  end

  def security_groups
    HashCollection.new(aws_ec2.security_groups)
  end

  def network_ports
    HashCollection.new(aws_ec2.client.describe_network_interfaces.network_interfaces)
  end

  def load_balancers
    HashCollection.new(aws_elb.client.describe_load_balancers.load_balancer_descriptions)
  end

  def health_check_members(load_balancer_name)
    HashCollection.new(aws_elb.client.describe_instance_health(
      :load_balancer_name => load_balancer_name).instance_states)
  end

  def floating_ips
    HashCollection.new(aws_ec2.client.describe_addresses.addresses)
  end

  def instances
    # TODO(lsmola) do the filtering on the API side
    HashCollection.new(aws_ec2.instances.select { |instance| instance.network_interfaces.blank? })
  end
end
