class ManageIQ::Providers::Amazon::Inventory::Collectors
  attr_reader :ems, :target, :options

  attr_reader :instances, :instances_refs, :instances_deleted
  attr_reader :flavors, :flavors_refs, :flavors_deleted
  attr_reader :availability_zones, :availability_zones_refs, :availability_zones_deleted
  attr_reader :key_pairs, :key_pairs_refs, :key_pairs_deleted
  attr_reader :private_images, :private_images_refs, :private_images_deleted
  attr_reader :shared_images, :shared_images_refs, :shared_images_deleted
  attr_reader :public_images, :public_images_refs, :public_images_deleted
  attr_reader :cloud_networks, :cloud_networks_refs, :cloud_networks_deleted
  attr_reader :cloud_subnets, :cloud_subnets_refs, :cloud_subnets_deleted
  attr_reader :security_groups, :security_groups_refs, :security_groups_deleted
  attr_reader :floating_ips, :floating_ips_refs, :floating_ips_deleted
  attr_reader :network_ports, :network_ports_refs, :network_ports_deleted
  attr_reader :load_balancers, :load_balancers_refs, :load_balancers_deleted
  attr_reader :stacks, :stacks_refs, :stacks_deleted
  attr_reader :cloud_volumes, :cloud_volumes_refs
  attr_reader :cloud_volume_snapshots, :cloud_volume_snapshots_refs


  def initialize(ems, target)
    @ems     = ems
    @target  = target
    @options = Settings.ems_refresh[ems.class.ems_type]

    initialize_inventory_sources
  end

  def initialize_inventory_sources
    @instances                   = []
    @instances_refs              = Set.new
    @instances_deleted           = []
    @flavors                     = []
    @flavors_refs                = Set.new
    @flavors_deleted             = []
    @availability_zones          = []
    @availability_zones_refs     = Set.new
    @availability_zones_deleted  = []
    @key_pairs                   = []
    @key_pairs_refs              = Set.new
    @key_pairs_deleted           = []
    @private_images              = []
    @private_images_refs         = Set.new
    @private_images_deleted      = []
    @shared_images               = []
    @shared_images_refs          = Set.new
    @shared_images_deleted       = []
    @public_images               = []
    @public_images_refs          = Set.new
    @public_images_deleted       = []
    @cloud_networks              = []
    @cloud_networks_refs         = Set.new
    @cloud_networks_deleted      = []
    @cloud_subnets               = []
    @cloud_subnets_refs          = Set.new
    @cloud_subnets_deleted       = []
    @security_groups             = []
    @security_groups_refs        = Set.new
    @security_groups_deleted     = []
    @floating_ips                = []
    @floating_ips_refs           = Set.new
    @floating_ips_deleted        = []
    @network_ports               = []
    @network_ports_refs          = Set.new
    @network_ports_deleted       = []
    @load_balancers              = []
    @load_balancers_refs         = Set.new
    @stacks                      = []
    @stacks_refs                 = Set.new
    @cloud_volumes               = []
    @cloud_volumes_refs          = Set.new
    @cloud_volume_snapshots      = []
    @cloud_volume_snapshots_refs = Set.new
    # Nested resources
    @stack_resources             = {}
    @stack_resources_refs        = {}
    @stack_template              = {}
    @stack_template_refs         = {}
    @health_check_members        = {}
    @health_check_members_refs   = {}
  end

  def hash_collection
    ::ManageIQ::Providers::Amazon::Inventory::HashCollection
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

  def aws_s3
    @aws_s3 ||= ems.connect(:service => :S3)
  end

  def stack_resources(stack_name)
    @stack_resources.try(:[], stack_name) || []
  end

  def stack_resources_refs(stack_name)
    @stack_resources_refs.try(:[], stack_name) || []
  end

  def stack_template(stack_name)
    @stack_template.try(:[], stack_name) || []
  end

  def stack_template_refs(stack_name)
    @stack_template_refs.try(:[], stack_name) || []
  end

  def health_check_members(load_balancer_name)
    @health_check_members.try(:[], load_balancer_name) || []
  end

  def health_check_members_refs(load_balancer_name)
    @health_check_members_refs.try(:[], load_balancer_name) || []
  end
end
