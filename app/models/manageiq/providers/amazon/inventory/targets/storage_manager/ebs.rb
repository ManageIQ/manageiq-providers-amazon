class ManageIQ::Providers::Amazon::Inventory::Targets::StorageManager::Ebs < ManageIQ::Providers::Amazon::Inventory::Targets
  def initialize_collector
    ManageIQ::Providers::Amazon::Inventory::Collectors::StorageManager::Ebs.new(ems, target)
  end

  def initialize_inventory_collections
    add_inventory_collections(%i(cloud_volumes cloud_volume_snapshots))

    add_inventory_collections(%i(availability_zones),
                              :parent   => ems.parent_manager,
                              :strategy => :local_db_cache_all)
  end
end
