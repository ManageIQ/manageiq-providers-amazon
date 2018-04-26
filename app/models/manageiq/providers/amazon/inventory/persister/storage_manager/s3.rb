class ManageIQ::Providers::Amazon::Inventory::Persister::StorageManager::S3 < ManageIQ::Providers::Amazon::Inventory::Persister
  include ManageIQ::Providers::Amazon::Inventory::Persister::Shared::StorageCollections

  def initialize_inventory_collections
    initialize_storage_inventory_collections
  end

  def initialize_storage_inventory_collections
    add_cloud_object_store_containers

    add_cloud_object_store_objects
  end
end
