class ManageIQ::Providers::Amazon::Inventory::Collector::CloudManager < ManageIQ::Providers::Amazon::Inventory::Collector
  def instances
    @instances_hashes ||= hash_collection.new(aws_ec2.instances).all
  end

  def flavors
    ManageIQ::Providers::Amazon::InstanceTypes.all
  end

  def availability_zones
    hash_collection.new(aws_ec2.client.describe_availability_zones.flat_map(&:availability_zones))
  end

  def key_pairs
    hash_collection.new(aws_ec2.client.describe_key_pairs.flat_map(&:key_pairs))
  end

  def cloud_database_flavors
    ManageIQ::Providers::Amazon::DatabaseTypes.all
  end

  def cloud_databases
    hash_collection.new(aws_rds.client.describe_db_instances.flat_map(&:db_instances))
  end

  def private_images
    return [] unless options.get_private_images

    @private_images_hashes ||= hash_collection.new(
      aws_ec2.client.describe_images(:owners  => [:self],
                                     :filters => [{:name   => "image-type",
                                                   :values => ["machine"]}]).flat_map(&:images)
    ).all
  end

  def shared_images
    return [] unless options.get_shared_images

    @shared_images_hashes ||= hash_collection.new(
      aws_ec2.client.describe_images(:executable_users => [:self],
                                     :filters          => [{:name   => "image-type",
                                                            :values => ["machine"]}]).flat_map(&:images)
    ).all
  end

  def public_images
    return [] unless options.get_public_images

    @public_images_hashes ||= hash_collection.new(
      aws_ec2.client.describe_images(:executable_users => [:all],
                                     :filters          => options.to_hash[:public_images_filters]).flat_map(&:images)
    ).all
  end

  def referenced_images
    return [] if extra_image_references.blank?

    multi_query(extra_image_references) do |refs|
      hash_collection.new(
        aws_ec2.client.describe_images(:filters => [{:name => 'image-id', :values => refs}]).flat_map(&:images)
      ).all
    end
  end

  def stacks
    hash_collection.new(aws_cloud_formation.client.describe_stacks.flat_map(&:stacks))
  end

  def stack_resources(stack_name)
    stack_resources = aws_cloud_formation.client.list_stack_resources(:stack_name => stack_name)

    if stack_resources.respond_to?(:stack_resource_summaries)
      stack_resources = stack_resources.flat_map(&:stack_resource_summaries)
    else
      stack_resources = nil
    end

    hash_collection.new(stack_resources || [])
  end

  def stack_template(stack_name)
    aws_cloud_formation.client.get_template(:stack_name => stack_name).template_body
  end

  def service_offerings
    aws_service_catalog.client.search_products_as_admin.product_view_details
  rescue => _e
    # TODO(lsmola) do not pollute log for now, since ServiceCatalog is not officially supported
    # _log.warn("Couldn't fetch 'search_products_as_admin' of service catalog, message: #{e.message}")
    []
  end

  def service_instances
    aws_service_catalog.client.scan_provisioned_products.provisioned_products
  rescue => _e
    # TODO(lsmola) do not pollute log for now, since ServiceCatalog is not officially supported
    # _log.warn("Couldn't fetch 'provisioned_products' of service catalog, message: #{e.message}")
    []
  end

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
  end

  def health_check_members(load_balancer_name)
    hash_collection.new(aws_elb.client.describe_instance_health(
      :load_balancer_name => load_balancer_name
    ).flat_map(&:instance_states))
  end

  def floating_ips
    hash_collection.new(aws_ec2.client.describe_addresses.flat_map(&:addresses))
  end

  def network_routers
    hash_collection.new(aws_ec2.route_tables)
  end

  def cloud_volumes
    hash_collection.new(aws_ec2.client.describe_volumes.flat_map(&:volumes))
  end

  def cloud_volume_snapshots
    hash_collection.new(aws_ec2.client.describe_snapshots(:owner_ids => [:self]).flat_map(&:snapshots))
  end

  private

  def extra_image_references
    # The references to images that are not collected by private_images, shared_images or public_images but that are
    # referenced by instances. Which can be caused e.g. by using a public_image while not collecting it under
    # public_images
    return @extra_image_references if @extra_image_references

    instances_image_refs = Set.new(instances.map { |x| x["image_id"] })
    api_images_refs      = Set.new((private_images + shared_images + public_images).map { |x| x["image_id"] })

    @extra_image_references = (instances_image_refs - api_images_refs).to_a
  end
end
