class ManageIQ::Providers::Amazon::Inventory::Persister::TargetCollection < ManageIQ::Providers::Amazon::Inventory::Persister
  include ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::CloudCollections
  include ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::NetworkCollections
  include ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::StorageCollections

  def targeted?
    true
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
    initialize_ebs_storage_inventory_collections
    initialize_s3_storage_inventory_collections if manager.s3_storage_manager
  end
end
