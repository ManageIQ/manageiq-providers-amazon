class ManageIQ::Providers::Amazon::InventoryCollectionDefault::NetworkManager < ManagerRefresh::InventoryCollectionDefault::NetworkManager
  class << self
    def network_ports(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::NetworkManager::NetworkPort,
        :inventory_object_attributes => [
          :type,
          :ems_id,
          :name,
          :ems_ref,
          :status,
          :mac_address,
          :device_owner,
          :device_ref,
          :device,
          :security_groups,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def cloud_subnet_network_ports(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :address,
          :cloud_subnet,
          :network_port,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def floating_ips(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::NetworkManager::FloatingIp,
        :inventory_object_attributes => [
          :type,
          :ems_id,
          :ems_ref,
          :address,
          :fixed_ip_address,
          :cloud_network_only,
          :cloud_network,
          :network_port,
          :status,
          :vm,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def cloud_subnets(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet,
        :inventory_object_attributes => [
          :type,
          :ems_id,
          :ems_ref,
          :name,
          :cidr,
          :status,
          :availability_zone,
          :cloud_network,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def cloud_networks(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::NetworkManager::CloudNetwork,
        :inventory_object_attributes => [
          :type,
          :ems_id,
          :ems_ref,
          :name,
          :cidr,
          :status,
          :enabled,
          :orchestration_stack,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def security_groups(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup,
        :inventory_object_attributes => [
          :type,
          :ems_id,
          :ems_ref,
          :name,
          :description,
          :cloud_network,
          :orchestration_stack,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def firewall_rules(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :direction,
          :host_protocol,
          :port,
          :end_port,
          :resource,
          :source_security_group,
          :source_ip_range,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def load_balancers(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer,
        :inventory_object_attributes => [
          :type,
          :ems_id,
          :ems_ref,
          :name,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def load_balancer_pools(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPool,
        :inventory_object_attributes => [
          :type,
          :ems_id,
          :ems_ref,
          :name,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def load_balancer_pool_members(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPoolMember,
        :inventory_object_attributes => [
          :type,
          :ems_id,
          :ems_ref,
          :vm,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def load_balancer_pool_member_pools(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :load_balancer_pool,
          :load_balancer_pool_member,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def load_balancer_listeners(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener,
        :inventory_object_attributes => [
          :type,
          :ems_id,
          :ems_ref,
          :load_balancer_protocol,
          :load_balancer_port_range,
          :instance_protocol,
          :instance_port_range,
          :load_balancer,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def load_balancer_listener_pools(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :load_balancer_listener,
          :load_balancer_pool,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def load_balancer_health_checks(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerHealthCheck,
        :inventory_object_attributes => [
          :type,
          :ems_id,
          :ems_ref,
          :protocol,
          :port,
          :url_path,
          :interval,
          :timeout,
          :unhealthy_threshold,
          :healthy_threshold,
          :load_balancer,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def load_balancer_health_check_members(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :load_balancer_health_check,
          :load_balancer_pool_member,
          :status,
          :status_reason,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end
  end
end
