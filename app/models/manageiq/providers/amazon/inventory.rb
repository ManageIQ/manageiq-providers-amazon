class ManageIQ::Providers::Amazon::Inventory
  require_nested :Factory
  require_nested :HashCollection
  require_nested :Targets

  attr_reader :ems, :target, :inventory_collections, :options

  def initialize(ems, target)
    @ems                   = ems
    @target                = target
    @options               = Settings.ems_refresh[ems.class.ems_type]
    @inventory_collections = {:_inventory_collection => true}

    @known_flavors = Set.new

    initialize_inventory_collections
  end

  def aws_ec2
    @aws_ec2 ||= ems.connect
  end

  def aws_cloud_formation
    @aws_cloud_formation ||= ems.connect(:service => :CloudFormation)
  end

  def aws_elb
    @aws_elb ||= ems.connect(:service => :ElasticLoadBalancing)
  end

  def instances
    []
  end

  def flavors
    []
  end

  def availability_zones
    []
  end

  def key_pairs
    []
  end

  def private_images
    []
  end

  def shared_images
    []
  end

  def public_images
    []
  end

  def stacks
    []
  end

  def stack_resources(_stack_name)
    []
  end

  def stack_template(_stack_name)
    []
  end

  def cloud_networks
    []
  end

  def cloud_subnets
    []
  end

  def security_groups
    []
  end

  def network_ports
    []
  end

  def load_balancers
    []
  end

  def health_check_members(load_balancer_name)
    []
  end

  def floating_ips
    []
  end

  def instances
    []
  end
end
