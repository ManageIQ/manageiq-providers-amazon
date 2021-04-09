class ManageIQ::Providers::Amazon::Inventory::Persister::CloudManager < ManageIQ::Providers::Amazon::Inventory::Persister
  include ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::CloudCollections
  include ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::NetworkCollections
  include ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::StorageCollections

  def initialize_inventory_collections
    initialize_tag_mapper

    initialize_cloud_inventory_collections
    initialize_network_inventory_collections
    initialize_storage_inventory_collections
  end

  def initialize_network_inventory_collections
    super
    add_network_collection(:network_routers)
  end

  def initialize_storage_inventory_collections
    initialize_ebs_storage_inventory_collections
  end
end
