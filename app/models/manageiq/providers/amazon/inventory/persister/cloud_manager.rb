class ManageIQ::Providers::Amazon::Inventory::Persister::CloudManager < ManageIQ::Providers::Amazon::Inventory::Persister
  include ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::CloudCollections

  def initialize_inventory_collections
    initialize_tag_mapper

    initialize_cloud_inventory_collections
  end
end
