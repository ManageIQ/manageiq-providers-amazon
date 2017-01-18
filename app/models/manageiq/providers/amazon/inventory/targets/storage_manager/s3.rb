class ManageIQ::Providers::Amazon::Inventory::Targets::StorageManager::S3 <
  ManageIQ::Providers::Amazon::Inventory::Targets
  def initialize_inventory_collections
    add_inventory_collections(%i(cloud_object_store_containers cloud_object_store_objects))
  end

  def cloud_object_store_containers
    HashCollection.new(aws_s3.client.list_buckets.buckets)
  end

  def cloud_object_store_objects
    HashCollection.new([])
  end
end
