class ManageIQ::Providers::Amazon::Inventory::Targets::CloudManager < ManageIQ::Providers::Amazon::Inventory::Targets
  def initialize_inventory_collections
    add_inventory_collections(%i(vms miq_templates hardwares networks disks availability_zones availability_zones
                                 flavors key_pairs orchestration_stacks orchestration_stacks_resources
                                 orchestration_stacks_outputs orchestration_stacks_parameters orchestration_templates))

    vm_and_miq_template_ancestry_save_block = lambda do |_ems, inventory_collection|
      # Fetch IDs of all vms and genealogy_parents, only if genealogy_parent is present
      vms_genealogy_parents = inventory_collection.dependency_attributes[:vms].first.data.each_with_object({}) do |x, obj|
        genealogy_parent_id = x.data[:genealogy_parent].load.try(:id)
        obj[x.id]           = genealogy_parent_id if genealogy_parent_id
      end

      miq_templates = ManageIQ::Providers::Amazon::CloudManager::Template.select([:id]).
        where(:id => vms_genealogy_parents.values).find_each.index_by(&:id)

      ManageIQ::Providers::Amazon::CloudManager::Vm.select([:id]).
        where(:id => vms_genealogy_parents.keys).find_each do |vm|

        parent = miq_templates[vms_genealogy_parents[vm.id]]
        parent.with_relationship_type('genealogy') { parent.set_child(vm) }
      end
    end

    add_inventory_collection(
      [
        ManageIQ::Providers::Amazon::CloudManager::Vm,
        :custom_save_block     => vm_and_miq_template_ancestry_save_block,
        :dependency_attributes => {:vms           => [inventory_collections[:vms]],
                                   :miq_templates => [inventory_collections[:miq_templates]]}],
      :vm_and_miq_template_ancestry)

    orchestration_stack_ancestry_save_block = lambda do |_ems, inventory_collection|
      stacks_parents = inventory_collection.dependency_attributes[:orchestration_stacks].first.data.each_with_object({}) do |x, obj|
        parent_id = x.data[:parent].load.try(:id)
        obj[x.id] = parent_id if parent_id
      end

      stacks_parents_indexed = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack.select([:id, :ancestry]).
        where(:id => stacks_parents.values).find_each.index_by(&:id)

      ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack.select([:id, :ancestry]).
        where(:id => stacks_parents.keys).find_each do |stack|

        parent = stacks_parents_indexed[stacks_parents[stack.id]]
        stack.update_attribute(:parent, parent)
      end
    end

    add_inventory_collection(
      [
        ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack,
        :custom_save_block     => orchestration_stack_ancestry_save_block,
        :dependency_attributes => {:orchestration_stacks           => [inventory_collections[:orchestration_stacks]],
                                   :orchestration_stacks_resources => [inventory_collections[:orchestration_stacks_resources]]}],
      :orchestration_stack_ancestry_)
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
