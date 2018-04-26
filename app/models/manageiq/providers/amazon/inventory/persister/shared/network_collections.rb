module ManageIQ::Providers::Amazon::Inventory::Persister::Shared::NetworkCollections
  extend ActiveSupport::Concern

  included do
    # Builder class for Network
    def network
      ::ManagerRefresh::InventoryCollection::Builder::NetworkManager
    end

    def add_cloud_subnet_network_ports(extra_properties = {})
      add_collection(network, :cloud_subnet_network_ports, extra_properties) do |builder|
        builder.add_properties(
          :manager_ref_allowed_nil => %i(cloud_subnet)
        )
      end
    end

    def add_firewall_rules(extra_properties = {})
      add_collection(network, :firewall_rules, extra_properties) do |builder|
        builder.add_properties(
          :manager_ref_allowed_nil => %i(source_security_group)
        )
      end
    end
  end
end
