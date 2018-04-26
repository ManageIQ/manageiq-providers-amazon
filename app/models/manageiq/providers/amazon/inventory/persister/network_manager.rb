class ManageIQ::Providers::Amazon::Inventory::Persister::NetworkManager < ManageIQ::Providers::Amazon::Inventory::Persister
  include ManageIQ::Providers::Amazon::Inventory::Persister::Shared::CloudCollections
  include ManageIQ::Providers::Amazon::Inventory::Persister::Shared::NetworkCollections

  def initialize_inventory_collections
    initialize_network_inventory_collections

    initialize_cloud_inventory_collections
  end

  private

  def initialize_network_inventory_collections
    %i(network_ports
       floating_ips
       cloud_subnets
       cloud_networks
       security_groups
       load_balancers
       load_balancer_pools
       load_balancer_pool_members
       load_balancer_pool_member_pools
       load_balancer_listeners
       load_balancer_listener_pools
       load_balancer_health_checks
       load_balancer_health_check_members
       network_routers).each do |name|

      add_collection(network, name)
    end

    add_cloud_subnet_network_ports

    add_firewall_rules
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
