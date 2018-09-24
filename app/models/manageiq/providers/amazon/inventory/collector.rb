class ManageIQ::Providers::Amazon::Inventory::Collector < ManageIQ::Providers::Inventory::Collector
  require_nested :CloudManager
  require_nested :NetworkManager
  require_nested :TargetCollection

  attr_reader :instances
  attr_reader :flavors
  attr_reader :availability_zones
  attr_reader :key_pairs
  attr_reader :private_images
  attr_reader :shared_images
  attr_reader :public_images
  attr_reader :cloud_networks
  attr_reader :cloud_subnets
  attr_reader :security_groups
  attr_reader :floating_ips
  attr_reader :network_ports
  attr_reader :network_routers
  attr_reader :load_balancers
  attr_reader :stacks
  attr_reader :cloud_volumes
  attr_reader :cloud_volume_snapshots
  attr_reader :cloud_objects_store_containers
  attr_reader :cloud_objects_store_objects

  def initialize(_manager, _target)
    super

    initialize_inventory_sources
  end

  def initialize_inventory_sources
    @instances                   = []
    @flavors                     = []
    @availability_zones          = []
    @key_pairs                   = []
    @private_images              = []
    @shared_images               = []
    @public_images               = []
    @cloud_networks              = []
    @cloud_subnets               = []
    @security_groups             = []
    @floating_ips                = []
    @network_ports               = []
    @network_routers             = []
    @load_balancers              = []
    @stacks                      = []
    @cloud_volumes               = []
    @cloud_volume_snapshots      = []
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
    @aws_ec2 ||= manager.connect
  end

  def aws_cloud_formation
    @aws_cloud_formation ||= manager.connect(:service => :CloudFormation)
  end

  def aws_service_catalog
    @aws_service_catalog ||= manager.connect(:service => :ServiceCatalog)
  end

  def aws_elb
    @aws_elb ||= manager.connect(:service => :ElasticLoadBalancing)
  end

  def aws_s3
    @aws_s3 ||= manager.connect(:service => :S3)
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

  def max_filter_size
    200
  end

  def multi_query(all_uuids)
    # AWS supports filtering only limited amount of items, so we need to send several queries
    all_uuids.each_slice(max_filter_size).map { |uuids_batch| yield(uuids_batch) }.flatten
  end

  def service_parameters_sets(product_id)
    # TODO(lsmola) too many API calls, we need to do it in multiple threads

    # Taking provisioning_artifacts of described product returns only active artifacts, doing list_provisioning_artifacts
    # we are not able to recognize the active ones. Same with describe_product_as_admin, status is missing. Status is
    # in the describe_provisioning_artifact, but it is wrong (always ACTIVE)
    artifacts    = aws_service_catalog.client.describe_product(:id => product_id).provisioning_artifacts
    launch_paths = aws_service_catalog.client.list_launch_paths(:product_id => product_id).launch_path_summaries
    parameters_sets = []

    launch_paths.each do |launch_path|
      artifacts.each do |artifact|
        parameter_set                           = {:artifact => artifact, :launch_path => launch_path}
        parameter_set[:provisioning_parameters] = aws_service_catalog.client.describe_provisioning_parameters(
          :product_id               => product_id,
          :provisioning_artifact_id => artifact.id,
          :path_id                  => launch_path.id
        )
        parameters_sets << parameter_set
      end
    end
    parameters_sets
  rescue => e
    _log.warn("Couldn't fetch 'describe_provisioning_parameters' of service catalog, message: #{e.message}")
    []
  end

  def describe_record(record_id)
    aws_service_catalog.client.describe_record(:id => record_id)
  rescue => e
    _log.warn("Couldn't fetch 'describe_record' of service catalog, message: #{e.message}")
    nil
  end
end
