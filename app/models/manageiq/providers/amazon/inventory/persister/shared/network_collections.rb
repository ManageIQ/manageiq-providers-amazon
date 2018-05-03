module ManageIQ::Providers::Amazon::Inventory::Persister::Shared::NetworkCollections
  extend ActiveSupport::Concern

  # Builder class for Network
  def network
    ::ManagerRefresh::InventoryCollection::Builder::NetworkManager
  end

  def initialize_network_inventory_collections
    %i(cloud_networks
       cloud_subnets
       security_groups
       load_balancers
       load_balancer_pools
       load_balancer_pool_members
       load_balancer_pool_member_pools
       load_balancer_listeners
       load_balancer_listener_pools
       load_balancer_health_checks
       load_balancer_health_check_members).each do |name|

      add_collection(network, name) do |builder|
        builder.add_properties(:parent => manager.network_manager) if targeted?
      end
    end

    add_cloud_subnet_network_ports

    add_firewall_rules

    add_floating_ips

    add_network_ports
  end

  # ------ IC provider specific definitions -------------------------

  def add_network_ports(extra_properties = {})
    add_collection(network, :network_ports, extra_properties) do |builder|
      if targeted?
        builder.add_properties(:manager_uuids => references(:vms) + references(:network_ports) + references(:load_balancers))
        builder.add_properties(:parent => manager.network_manager)
      end
    end
  end

  def add_floating_ips(extra_properties = {})
    add_collection(network, :floating_ips, extra_properties) do |builder|
      if targeted?
        builder.add_properties(:manager_uuids => references(:floating_ips) + references(:load_balancers))
        builder.add_properties(:parent => manager.network_manager)
      end
    end
  end

  def add_cloud_subnet_network_ports(extra_properties = {})
    add_collection(network, :cloud_subnet_network_ports, extra_properties) do |builder|
      builder.add_properties(:manager_ref_allowed_nil => %i(cloud_subnet))
      builder.add_properties(:parent => manager.network_manager) if targeted?
    end
  end

  def add_firewall_rules(extra_properties = {})
    add_collection(network, :firewall_rules, extra_properties) do |builder|
      builder.add_properties(:manager_ref_allowed_nil => %i(source_security_group))
      builder.add_properties(:parent => manager.network_manager) if targeted?
    end
  end
end
