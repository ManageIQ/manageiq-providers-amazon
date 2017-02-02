class ManageIQ::Providers::Amazon::Inventory::Collectors::NetworkManager < ManageIQ::Providers::Amazon::Inventory::Collectors
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

  def load_balancers
    hash_collection.new(aws_elb.client.describe_load_balancers.load_balancer_descriptions)
  end

  def health_check_members(load_balancer_name)
    hash_collection.new(aws_elb.client.describe_instance_health(
      :load_balancer_name => load_balancer_name).instance_states)
  end

  def floating_ips
    hash_collection.new(aws_ec2.client.describe_addresses.addresses)
  end

  def instances
    hash_collection.new(aws_ec2.instances)
  end
end
