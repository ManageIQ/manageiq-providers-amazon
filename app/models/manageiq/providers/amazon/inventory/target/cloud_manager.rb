class ManageIQ::Providers::Amazon::Inventory::Target::CloudManager < ManageIQ::Providers::Amazon::Inventory::Target
  def initialize_inventory_collections
    add_inventory_collections(
      cloud,
      %i(vms miq_templates hardwares networks disks availability_zones
         flavors key_pairs orchestration_stacks orchestration_stacks_resources
         orchestration_stacks_outputs orchestration_stacks_parameters orchestration_templates)
    )

    add_inventory_collection(
      cloud.vm_and_miq_template_ancestry(
        :dependency_attributes => {
          :vms           => [inventory_collections[:vms]],
          :miq_templates => [inventory_collections[:miq_templates]]
        }
      )
    )

    add_inventory_collection(
      cloud.orchestration_stack_ancestry(
        :dependency_attributes => {
          :orchestration_stacks           => [inventory_collections[:orchestration_stacks]],
          :orchestration_stacks_resources => [inventory_collections[:orchestration_stacks_resources]]
        }
      )
    )
  end
end
