class ManageIQ::Providers::Amazon::Inventory::Persister::TargetCollection < ManageIQ::Providers::Amazon::Inventory::Persister
  include ManageIQ::Providers::Amazon::Inventory::Persister::Shared::CloudCollections
  include ManageIQ::Providers::Amazon::Inventory::Persister::Shared::NetworkCollections
  include ManageIQ::Providers::Amazon::Inventory::Persister::Shared::StorageCollections

  def targeted?
    true
  end

  def strategy
    :local_db_find_missing_references
  end

  def initialize_inventory_collections
    initialize_tag_mapper

    initialize_cloud_inventory_collections

    initialize_network_inventory_collections

    initialize_storage_inventory_collections
  end

  private

  # Top level models with direct references for Network
  def initialize_storage_inventory_collections
    add_cloud_volumes

    add_cloud_volume_snapshots

    if manager.s3_storage_manager
      add_cloud_object_store_containers

      add_cloud_object_store_objects
    end
  end
end
