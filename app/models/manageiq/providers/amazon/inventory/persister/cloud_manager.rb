class ManageIQ::Providers::Amazon::Inventory::Persister::CloudManager < ManageIQ::Providers::Amazon::Inventory::Persister
  def initialize_inventory_collections
    initialize_tag_mapper

    add_inventory_collections(
      cloud,
      %i(vms miq_templates hardwares operating_systems networks disks availability_zones
         vm_and_template_labels vm_and_template_taggings
         flavors key_pairs orchestration_stacks orchestration_stacks_resources
         orchestration_stacks_outputs orchestration_stacks_parameters orchestration_templates)
    )

    add_inventory_collection(
      cloud.vm_and_miq_template_ancestry(
        :dependency_attributes => {
          :vms           => [collections[:vms]],
          :miq_templates => [collections[:miq_templates]]
        }
      )
    )

    add_inventory_collection(
      cloud.orchestration_stack_ancestry(
        :dependency_attributes => {
          :orchestration_stacks           => [collections[:orchestration_stacks]],
          :orchestration_stacks_resources => [collections[:orchestration_stacks_resources]]
        }
      )
    )
  end
end
