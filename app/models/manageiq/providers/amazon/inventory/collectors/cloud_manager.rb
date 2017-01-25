class ManageIQ::Providers::Amazon::Inventory::Collectors::CloudManager < ManageIQ::Providers::Amazon::Inventory::Collectors
  def instances
    hash_collection.new(aws_ec2.instances)
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
    hash_collection.new(aws_ec2.client.describe_images(:owners  => [:self],
                                                      :filters => [{:name   => "image-type",
                                                                    :values => ["machine"]}])[:images])
  end

  def shared_images
    hash_collection.new(aws_ec2.client.describe_images(:executable_users => [:self],
                                                      :filters          => [{:name   => "image-type",
                                                                             :values => ["machine"]}])[:images])
  end

  def public_images
    filters = options.public_images_filters
    hash_collection.new(aws_ec2.client.describe_images(:executable_users => [:all],
                                                      :filters          => filters)[:images])
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
end
