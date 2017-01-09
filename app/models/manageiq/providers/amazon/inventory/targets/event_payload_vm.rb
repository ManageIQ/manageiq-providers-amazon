class ManageIQ::Providers::Amazon::Inventory::Targets::EventPayloadVm < ManageIQ::Providers::Amazon::Inventory::Targets
  def initialize_inventory_collections
    instance_ems_ref = event_payload(target)["instance_id"]

    add_inventory_collection(
      vms_init_data(
        :arel => ems.vms.where(:ems_ref => instance_ems_ref)))
    add_inventory_collection(
      hardwares_init_data(
        :arel     => ems.hardwares.joins(:vm_or_template).where(:vms => {:ems_ref => instance_ems_ref}),
        :strategy => :find_missing_in_local_db))
    add_inventory_collection(
      disks_init_data(
        :arel => ems.disks.joins(:hardware => :vm_or_template).where(:hardware => {:vms => {:ems_ref => instance_ems_ref}})))
    add_inventory_collection(
      networks_init_data(
        :arel => ems.networks.joins(:hardware => :vm_or_template).where(:hardware => {:vms => {:ems_ref => instance_ems_ref}})))

    add_remaining_inventory_collections(:strategy => :local_db_find_one)
  end

  def instances
    [event_payload(target)]
  end
end
