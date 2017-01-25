class ManageIQ::Providers::Amazon::Inventory::Targets::NetworkManager < ManageIQ::Providers::Amazon::Inventory::Targets
  def initialize_collector
    ManageIQ::Providers::Amazon::Inventory::Collectors::NetworkManager.new(ems, target)
  end

  def initialize_inventory_collections
    add_inventory_collections(
      %i(cloud_subnet_network_ports network_ports floating_ips cloud_subnets cloud_networks security_groups
         firewall_rules load_balancers load_balancer_pools load_balancer_pool_members load_balancer_pool_member_pools
         load_balancer_listeners load_balancer_listener_pools load_balancer_health_checks
         load_balancer_health_check_members))

    add_inventory_collections(%i(vms orchestration_stacks availability_zones),
                              :parent   => ems.parent_manager,
                              :strategy => :local_db_cache_all)
  end
end
