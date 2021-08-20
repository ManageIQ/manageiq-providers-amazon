class ManageIQ::Providers::Amazon::Inventory::Collector::NetworkManager < ManageIQ::Providers::Amazon::Inventory::Collector
  def cloud_networks
    hash_collection.new(aws_ec2.client.describe_vpcs.flat_map(&:vpcs))
  end

  def cloud_subnets
    hash_collection.new(aws_ec2.client.describe_subnets.flat_map(&:subnets))
  end

  def security_groups
    hash_collection.new(aws_ec2.security_groups)
  end

  def network_ports
    hash_collection.new(aws_ec2.client.describe_network_interfaces.flat_map(&:network_interfaces))
  end

  def load_balancers
    hash_collection.new(aws_elb.client.describe_load_balancers.flat_map(&:load_balancer_descriptions))
  rescue
    # ELB is an optional service and failures shouldn't prevent the rest
    # of the refresh from succeeding
    []
  end

  def health_check_members(load_balancer_name)
    hash_collection.new(aws_elb.client.describe_instance_health(
      :load_balancer_name => load_balancer_name
    ).flat_map(&:instance_states))
  rescue
    # ELB is an optional service and failures shouldn't prevent the rest
    # of the refresh from succeeding
    []
  end

  def floating_ips
    hash_collection.new(aws_ec2.client.describe_addresses.flat_map(&:addresses))
  end

  def instances
    hash_collection.new(aws_ec2.instances)
  end

  def network_routers
    hash_collection.new(aws_ec2.route_tables)
  end
end
