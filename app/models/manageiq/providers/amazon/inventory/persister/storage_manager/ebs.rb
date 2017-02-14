class ManageIQ::Providers::Amazon::Inventory::Persister::StorageManager::Ebs < ManageIQ::Providers::Amazon::Inventory::Persister
  def initialize_inventory_collections
    add_inventory_collections(storage, %i(cloud_volumes cloud_volume_snapshots))

    add_inventory_collections(cloud, %i(availability_zones hardwares),
                              :parent   => manager.parent_manager,
                              :strategy => :local_db_cache_all)

    add_inventory_collections(cloud, %i(disks),
                              :parent      => manager.parent_manager,
                              :update_only => true)
  end
end
