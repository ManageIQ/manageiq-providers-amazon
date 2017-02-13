class ManageIQ::Providers::Amazon::InventoryCollectionDefault::NetworkManager < ManagerRefresh::InventoryCollectionDefault::NetworkManager
  class << self
    def network_ports(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::NetworkPort,
      }

      super(attributes.merge!(extra_attributes))
    end

    def floating_ips(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::FloatingIp,
      }

      super(attributes.merge!(extra_attributes))
    end

    def cloud_subnets(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet,
      }

      super(attributes.merge!(extra_attributes))
    end

    def cloud_networks(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::CloudNetwork,
      }

      super(attributes.merge!(extra_attributes))
    end

    def security_groups(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup,
      }

      super(attributes.merge!(extra_attributes))
    end

    def load_balancers(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer,
      }

      super(attributes.merge!(extra_attributes))
    end

    def load_balancer_pools(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPool,
      }

      super(attributes.merge!(extra_attributes))
    end

    def load_balancer_pool_members(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPoolMember,
      }

      super(attributes.merge!(extra_attributes))
    end

    def load_balancer_listeners(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener,
      }

      super(attributes.merge!(extra_attributes))
    end

    def load_balancer_health_checks(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerHealthCheck,
      }

      super(attributes.merge!(extra_attributes))
    end
  end
end
