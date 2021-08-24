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
  rescue
    # RDS is an optional collection and failures shouldn't prevent the rest of the refresh
    # from succeeding
    []
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
  rescue
    # CloudFormation is an optional service and failures shouldn't prevent the rest
    # of the refresh from succeeding
    []
  end

  def stack_resources(stack_name)
    stack_resources = aws_cloud_formation.client.list_stack_resources(:stack_name => stack_name)

    if stack_resources.respond_to?(:stack_resource_summaries)
      stack_resources = stack_resources.flat_map(&:stack_resource_summaries)
    else
      stack_resources = nil
    end

    hash_collection.new(stack_resources || [])
  rescue
    # CloudFormation is an optional service and failures shouldn't prevent the rest
    # of the refresh from succeeding
    []
  end

  def stack_template(stack_name)
    aws_cloud_formation.client.get_template(:stack_name => stack_name).template_body
  rescue
    # CloudFormation is an optional service and failures shouldn't prevent the rest
    # of the refresh from succeeding
    []
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
