class ManageIQ::Providers::Amazon::Inventory::Persister::StorageManager::S3 < ManageIQ::Providers::Amazon::Inventory::Persister
  def initialize_inventory_collections
    add_inventory_collections(storage, %i(cloud_object_store_containers cloud_object_store_objects))
  end
end
