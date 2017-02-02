class ManageIQ::Providers::Amazon::Inventory::Target::CloudManager < ManageIQ::Providers::Amazon::Inventory::Target
  def initialize_inventory_collections
    add_inventory_collections(%i(vms miq_templates hardwares networks disks availability_zones availability_zones
                                 flavors key_pairs orchestration_stacks orchestration_stacks_resources
                                 orchestration_stacks_outputs orchestration_stacks_parameters orchestration_templates))

    add_inventory_collection(
      vm_and_miq_template_ancestry_init_data(
        :dependency_attributes => {
          :vms           => [inventory_collections[:vms]],
          :miq_templates => [inventory_collections[:miq_templates]]}))

    add_inventory_collection(
      orchestration_stack_ancestry_init_data(
        :dependency_attributes => {
          :orchestration_stacks           => [inventory_collections[:orchestration_stacks]],
          :orchestration_stacks_resources => [inventory_collections[:orchestration_stacks_resources]]}))
  end
end
