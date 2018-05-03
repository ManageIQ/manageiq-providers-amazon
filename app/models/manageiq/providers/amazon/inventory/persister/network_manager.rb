class ManageIQ::Providers::Amazon::Inventory::Persister::NetworkManager < ManageIQ::Providers::Amazon::Inventory::Persister
  include ManageIQ::Providers::Amazon::Inventory::Persister::Shared::CloudCollections
  include ManageIQ::Providers::Amazon::Inventory::Persister::Shared::NetworkCollections

  def initialize_inventory_collections
    initialize_network_inventory_collections

    initialize_cloud_inventory_collections
  end

  def initialize_network_inventory_collections
    super

    add_collection(network, :network_routers)
  end

  def initialize_cloud_inventory_collections
    %i(vms
       availability_zones).each do |name|

      add_collection(cloud, name) do |builder|
        builder.add_properties(
          :parent   => manager.parent_manager,
          :strategy => :local_db_cache_all
        )
      end
    end

    add_orchestration_stacks(
      :parent   => manager.parent_manager,
      :strategy => :local_db_cache_all
    )
  end
end
