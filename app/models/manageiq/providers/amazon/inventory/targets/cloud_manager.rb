class ManageIQ::Providers::Amazon::Inventory::Targets::CloudManager < ManageIQ::Providers::Amazon::Inventory::Targets
  def initialize_inventory_collections
    add_inventory_collection(vms_init_data)
    add_inventory_collection(miq_templates_init_data)
    add_inventory_collection(hardwares_init_data)
    add_inventory_collection(networks_init_data)
    add_inventory_collection(disks_init_data)
    add_inventory_collection(availability_zones_init_data)
    add_inventory_collection(flavors_init_data)
    add_inventory_collection(key_pairs_init_data)
    add_inventory_collection(orchestration_stacks_init_data)
    add_inventory_collection(orchestration_stacks_resources_init_data)
    add_inventory_collection(orchestration_stacks_outputs_init_data)
    add_inventory_collection(orchestration_stacks_parameters_init_data)
    add_inventory_collection(orchestration_templates_init_data)
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
