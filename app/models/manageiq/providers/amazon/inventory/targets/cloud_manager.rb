class ManageIQ::Providers::Amazon::Inventory::Targets::CloudManager < ManageIQ::Providers::Amazon::Inventory::Targets
  def initialize_inventory_collections
    add_inventory_collections(%i(vms miq_templates hardwares networks disks availability_zones availability_zones
                                 flavors key_pairs orchestration_stacks orchestration_stacks_resources
                                 orchestration_stacks_outputs orchestration_stacks_parameters orchestration_templates))
  end

  def instances
    HashCollection.new(aws_ec2.instances)
  end

  def flavors
    ManageIQ::Providers::Amazon::InstanceTypes.all
  end

  def availability_zones
    HashCollection.new(aws_ec2.client.describe_availability_zones[:availability_zones])
  end

  def key_pairs
    HashCollection.new(aws_ec2.client.describe_key_pairs[:key_pairs])
  end

  def private_images
    HashCollection.new(aws_ec2.client.describe_images(:owners  => [:self],
                                                      :filters => [{:name   => "image-type",
                                                                    :values => ["machine"]}])[:images])
  end

  def shared_images
    HashCollection.new(aws_ec2.client.describe_images(:executable_users => [:self],
                                                      :filters          => [{:name   => "image-type",
                                                                             :values => ["machine"]}])[:images])
  end

  def public_images
    filters = options.public_images_filters
    HashCollection.new(aws_ec2.client.describe_images(:executable_users => [:all],
                                                      :filters          => filters)[:images])
  end

  def stacks
    HashCollection.new(aws_cloud_formation.client.describe_stacks[:stacks])
  end

  def stack_resources(stack_name)
    stack_resources = aws_cloud_formation.client.list_stack_resources(:stack_name => stack_name).try(:stack_resource_summaries)

    HashCollection.new(stack_resources || [])
  end

  def stack_template(stack_name)
    aws_cloud_formation.client.get_template(:stack_name => stack_name).template_body
  end
end
