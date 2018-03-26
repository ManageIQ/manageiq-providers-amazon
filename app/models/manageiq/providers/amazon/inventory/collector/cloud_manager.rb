class ManageIQ::Providers::Amazon::Inventory::Collector::CloudManager < ManageIQ::Providers::Amazon::Inventory::Collector
  def instances
    @instances_hashes ||= hash_collection.new(aws_ec2.instances).all
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

    @private_images_hashes ||= hash_collection.new(
      aws_ec2.client.describe_images(:owners  => [:self],
                                     :filters => [{:name   => "image-type",
                                                   :values => ["machine"]}]).images
    ).all
  end

  def shared_images
    return [] unless options.get_shared_images

    @shared_images_hashes ||= hash_collection.new(
      aws_ec2.client.describe_images(:executable_users => [:self],
                                     :filters          => [{:name   => "image-type",
                                                            :values => ["machine"]}]).images
    ).all
  end

  def public_images
    return [] unless options.get_public_images

    @public_images_hashes ||= hash_collection.new(
      aws_ec2.client.describe_images(:executable_users => [:all],
                                     :filters          => options.to_hash[:public_images_filters]).images
    ).all
  end

  def referenced_images
    return [] if extra_image_references.blank?

    hash_collection.new(
      aws_ec2.client.describe_images(:filters => [{:name => 'image-id', :values => extra_image_references}]).images
    )
  end

  def stacks
    hash_collection.new(aws_cloud_formation.client.describe_stacks[:stacks])
  end

  def stack_resources(stack_name)
    stack_resources = aws_cloud_formation.client.list_stack_resources(:stack_name => stack_name).try(:stack_resource_summaries)

    hash_collection.new(stack_resources || [])
  end

  def stack_template(stack_name)
    aws_cloud_formation.client.get_template(:stack_name => stack_name).template_body
  end

  private

  def extra_image_references
    # The references to images that are not collected by private_images, shared_images or public_images but that are
    # referenced by instances. Which can be caused e.g. by using a public_image while not collecting it under
    # public_images
    return @extra_image_references if @extra_image_references

    db_image_refs        = Set.new(manager.miq_templates.pluck(:ems_ref))
    instances_image_refs = Set.new(instances.map { |x| x["image_id"] })
    api_images_refs      = Set.new((private_images + shared_images + public_images).map { |x| x["image_id"] })

    @extra_image_references = ((db_image_refs + instances_image_refs) - api_images_refs).to_a
  end
end
