class ManageIQ::Providers::Amazon::Inventory::Targets::StorageManager::S3 <
  ManageIQ::Providers::Amazon::Inventory::Targets

  def initialize_collector
    ManageIQ::Providers::Amazon::Inventory::Collectors::StorageManager::S3.new(ems, target)
  end

  def initialize_inventory_collections
    add_inventory_collections(%i(cloud_object_store_containers cloud_object_store_objects))
  end
end
