class ManageIQ::Providers::Amazon::Inventory::Targets::NetworkManager < ManageIQ::Providers::Amazon::Inventory::Targets
  def initialize_inventory_collections
    add_inventory_collection(cloud_subnet_network_ports_init_data)
    add_inventory_collection(network_ports_init_data)
    add_inventory_collection(floating_ips_init_data)
    add_inventory_collection(cloud_subnets_init_data)
    add_inventory_collection(cloud_networks_init_data)
    add_inventory_collection(security_groups_init_data)
    add_inventory_collection(firewall_rules_init_data)
    add_inventory_collection(load_balancers_init_data)
    add_inventory_collection(load_balancer_pools_init_data)
    add_inventory_collection(load_balancer_pool_members_init_data)
    add_inventory_collection(load_balancer_pool_member_pools_init_data)
    add_inventory_collection(load_balancer_listeners_init_data)
    add_inventory_collection(load_balancer_listener_pools_init_data)
    add_inventory_collection(load_balancer_health_checks_init_data)
    add_inventory_collection(load_balancer_health_check_members_init_data)

    add_inventory_collection(vms_init_data(:parent   => ems.parent_manager,
                                           :strategy => :local_db_cache_all))
    add_inventory_collection(orchestration_stacks_init_data(:parent   => ems.parent_manager,
                                                            :strategy => :local_db_cache_all))
    add_inventory_collection(availability_zones_init_data(:parent   => ems.parent_manager,
                                                          :strategy => :local_db_cache_all))
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
