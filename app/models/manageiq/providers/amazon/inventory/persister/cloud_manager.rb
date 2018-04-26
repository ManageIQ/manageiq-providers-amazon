class ManageIQ::Providers::Amazon::Inventory::Persister::CloudManager < ManageIQ::Providers::Amazon::Inventory::Persister
  include ManageIQ::Providers::Amazon::Inventory::Persister::Shared::CloudCollections

  def initialize_inventory_collections
    initialize_tag_mapper

    %i(vms
       hardwares
       operating_systems
       networks
       disks
       flavors
       availability_zones).each do |name|

      add_collection(cloud, name)
    end

    add_miq_templates

    add_key_pairs

    add_orchestration_stacks

    add_vm_and_template_labels

    add_vm_and_template_taggings

    %i(orchestration_stacks_resources
       orchestration_stacks_outputs
       orchestration_stacks_parameters
       orchestration_templates).each do |name|

      add_collection(cloud, name)
    end

    add_vm_and_miq_template_ancestry

    add_orchestration_stack_ancestry
  end
end
