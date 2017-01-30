class ManageIQ::Providers::Amazon::Inventory::Target::StorageManager::Ebs < ManageIQ::Providers::Amazon::Inventory::Target
  def initialize_inventory_collections
    add_inventory_collections(%i(cloud_volumes cloud_volume_snapshots))

    add_inventory_collections(%i(availability_zones hardwares),
                              :parent   => ems.parent_manager,
                              :strategy => :local_db_cache_all)

    add_inventory_collections(%i(disks),
                              :parent      => ems.parent_manager,
                              :update_only => true)
  end
end
