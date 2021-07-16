class ManageIQ::Providers::Amazon::Inventory::Persister::StorageManager::S3 < ManageIQ::Providers::Amazon::Inventory::Persister
  include ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::StorageCollections

  def initialize_inventory_collections
    initialize_s3_storage_inventory_collections
  end
end
