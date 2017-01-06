class ManageIQ::Providers::Amazon::Inventory::Targets::EventPayloadVm < ManageIQ::Providers::Amazon::Inventory::Targets
  def initialize_inventory_collections
    instance_ems_ref = event_payload(target)["instance_id"]

    add_inventory_collection(
      vms_init_data(
        :arel => ems.vms.where(:ems_ref => instance_ems_ref)))
    add_inventory_collection(
      hardwares_init_data(
        :arel => ems.hardwares.joins(:vm_or_template).where(:vms => {:ems_ref => instance_ems_ref})))
    add_inventory_collection(
      disks_init_data(
        :arel => ems.disks.joins(:hardware => :vm_or_template).where(:hardware => {:vms => {:ems_ref => instance_ems_ref}})))
    add_inventory_collection(
      networks_init_data(
        :arel => ems.networks.joins(:hardware => :vm_or_template).where(:hardware => {:vms => {:ems_ref => instance_ems_ref}})))

    add_inventory_collection(flavors_init_data(:strategy => :local_db_cache_all))
    add_inventory_collection(miq_templates_init_data(:strategy => :local_db_cache_all))
    add_inventory_collection(availability_zones_init_data(:strategy => :local_db_cache_all))
    add_inventory_collection(key_pairs_init_data(:strategy => :local_db_cache_all))
    add_inventory_collection(orchestration_stacks_init_data(:strategy => :local_db_cache_all))
    add_inventory_collection(orchestration_stacks_resources_init_data(:strategy => :local_db_cache_all))
    add_inventory_collection(orchestration_stacks_outputs_init_data(:strategy => :local_db_cache_all))
    add_inventory_collection(orchestration_stacks_parameters_init_data(:strategy => :local_db_cache_all))
    add_inventory_collection(orchestration_templates_init_data(:strategy => :local_db_cache_all))
  end

  def instances
    [event_payload(target)]
  end
end
