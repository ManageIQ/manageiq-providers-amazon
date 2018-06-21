class ManageIQ::Providers::Amazon::Inventory::Persister::NetworkManager < ManageIQ::Providers::Amazon::Inventory::Persister
  include ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::CloudCollections
  include ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::NetworkCollections

  def initialize_inventory_collections
    initialize_network_inventory_collections

    initialize_cloud_inventory_collections
  end

  def initialize_network_inventory_collections
    super

    add_collection(network, :network_routers)
  end

  def initialize_cloud_inventory_collections
    %i(availability_zones
       orchestration_stacks
       vms).each do |name|

      add_collection(cloud, name) do |builder|
        builder.add_properties(
          :parent   => manager.parent_manager,
          :strategy => :local_db_cache_all
        )
      end
    end
  end
end
