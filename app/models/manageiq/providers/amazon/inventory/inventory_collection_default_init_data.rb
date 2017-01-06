module ManageIQ::Providers::Amazon::Inventory::InventoryCollectionDefaultInitData
  def init_data(model_class, attributes, extra_attributes)
    init_data = {
      :delete_method => model_class.new.respond_to?(:disconnect_inv) ? :disconnect_inv : nil
    }

    init_data.merge!(attributes).merge!(extra_attributes)
    return model_class, init_data
  end

  def vms_init_data(extra_attributes = {})
    attributes = {
      :association => :vms,
    }

    init_data(::ManageIQ::Providers::Amazon::CloudManager::Vm, attributes, extra_attributes)
  end

  def miq_templates_init_data(extra_attributes = {})
    attributes = {
      :association => :miq_templates,
    }

    init_data(::ManageIQ::Providers::Amazon::CloudManager::Template, attributes, extra_attributes)
  end

  def availability_zones_init_data(extra_attributes = {})
    attributes = {
      :association => :availability_zones,
    }

    init_data(::ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone, attributes, extra_attributes)
  end

  def flavors_init_data(extra_attributes = {})
    attributes = {
      :association => :flavors,
    }

    init_data(::ManageIQ::Providers::Amazon::CloudManager::Flavor, attributes, extra_attributes)
  end

  def key_pairs_init_data(extra_attributes = {})
    attributes = {
      :manager_ref => [:name],
      :association => :key_pairs
    }

    init_data(::ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair, attributes, extra_attributes)
  end

  def hardwares_init_data(extra_attributes = {})
    attributes = {
      :manager_ref => [:vm_or_template],
      :association => :hardwares
    }

    if extra_attributes[:strategy] == :local_db_cache_all
      attributes[:custom_manager_uuid] = lambda do |hardware|
        [hardware.vm_or_template.ems_ref]
      end
    end

    init_data(::Hardware, attributes, extra_attributes)
  end

  def disks_init_data(extra_attributes = {})
    attributes = {
      :manager_ref => [:hardware, :device_name],
      :association => :disks
    }

    if extra_attributes[:strategy] == :local_db_cache_all
      attributes[:custom_manager_uuid] = lambda do |disk|
        [disk.hardware.vm_or_template.ems_ref, disk.device_name]
      end
    end

    init_data(::Disk, attributes, extra_attributes)
  end

  def networks_init_data(extra_attributes = {})
    attributes = {
      :manager_ref => [:hardware, :description],
      :association => :networks
    }

    if extra_attributes[:strategy] == :local_db_cache_all
      attributes[:custom_manager_uuid] = lambda do |network|
        [network.hardware.vm_or_template.ems_ref, network.description]
      end
    end

    init_data(::Network, attributes, extra_attributes)
  end

  def orchestration_stacks_init_data(extra_attributes = {})
    attributes = {
      :association => :orchestration_stacks,
    }

    init_data(::ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack, attributes, extra_attributes)
  end

  def orchestration_stacks_resources_init_data(extra_attributes = {})
    attributes = {
      :association => :orchestration_stacks_resources,
    }

    init_data(::OrchestrationStackResource, attributes, extra_attributes)
  end

  def orchestration_stacks_outputs_init_data(extra_attributes = {})
    attributes = {
      :association => :orchestration_stacks_outputs,
    }

    init_data(::OrchestrationStackOutput, attributes, extra_attributes)
  end

  def orchestration_stacks_parameters_init_data(extra_attributes = {})
    attributes = {
      :association => :orchestration_stacks_parameters,
    }

    init_data(::OrchestrationStackParameter, attributes, extra_attributes)
  end

  def orchestration_templates_init_data(extra_attributes = {})
    # TODO(lsmola) do refactoring, we shouldn't need this custom saving block
    orchestration_template_save_block = lambda do |_ems, inventory_collection|
      hashes = inventory_collection.data.map(&:attributes)

      templates = ::OrchestrationTemplate.find_or_create_by_contents(hashes)
      inventory_collection.data.zip(templates).each { |inventory_object, template| inventory_object.object = template }
    end

    attributes = {
      :association       => :orchestration_templates,
      :custom_save_block => orchestration_template_save_block
    }

    init_data(::OrchestrationTemplateCfn, attributes, extra_attributes)
  end

  def cloud_subnet_network_ports_init_data(extra_attributes = {})
    attributes = {
      :manager_ref => [:address, :cloud_subnet, :network_port],
      :association => :cloud_subnet_network_ports,
    }

    init_data(::CloudSubnetNetworkPort, attributes, extra_attributes)
  end

  def network_ports_init_data(extra_attributes = {})
    attributes = {
      :association => :network_ports,
    }

    init_data(::ManageIQ::Providers::Amazon::NetworkManager::NetworkPort, attributes, extra_attributes)
  end

  def floating_ips_init_data(extra_attributes = {})
    attributes = {
      :association => :floating_ips,
    }

    init_data(::ManageIQ::Providers::Amazon::NetworkManager::FloatingIp, attributes, extra_attributes)
  end

  def cloud_subnets_init_data(extra_attributes = {})
    attributes = {
      :association => :cloud_subnets,
    }

    init_data(::ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet, attributes, extra_attributes)
  end

  def cloud_networks_init_data(extra_attributes = {})
    attributes = {
      :association => :cloud_networks,
    }

    init_data(ManageIQ::Providers::Amazon::NetworkManager::CloudNetwork, attributes, extra_attributes)
  end

   def security_groups_init_data(extra_attributes = {})
    attributes = {
      :association => :security_groups,
    }

    init_data(::ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup, attributes, extra_attributes)
  end

  def firewall_rules_init_data(extra_attributes = {})
    attributes = {
      :manager_ref => [:resource, :source_security_group, :direction, :host_protocol, :port, :end_port, :source_ip_range],
      :association => :firewall_rules,
    }

    init_data(::FirewallRule, attributes, extra_attributes)
  end

  def load_balancers_init_data(extra_attributes = {})
    attributes = {
      :association => :load_balancers,
    }

    init_data(::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer, attributes, extra_attributes)
  end

  def load_balancer_pools_init_data(extra_attributes = {})
    attributes = {
      :association => :load_balancer_pools,
    }

    init_data(::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPool, attributes, extra_attributes)
  end

  def load_balancer_pool_members_init_data(extra_attributes = {})
    attributes = {
      :association => :load_balancer_pool_members,
    }

    init_data(::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPoolMember, attributes, extra_attributes)
  end

  def load_balancer_pool_member_pools_init_data(extra_attributes = {})
    attributes = {
      :manager_ref => [:load_balancer_pool, :load_balancer_pool_member],
      :association => :load_balancer_pool_member_pools,
    }

    init_data(::LoadBalancerPoolMemberPool, attributes, extra_attributes)
  end

  def load_balancer_listeners_init_data(extra_attributes = {})
    attributes = {
      :association => :load_balancer_listeners,
    }

    init_data(::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener, attributes, extra_attributes)
  end

  def load_balancer_listener_pools_init_data(extra_attributes = {})
    attributes = {
      :manager_ref => [:load_balancer_listener, :load_balancer_pool],
      :association => :load_balancer_listener_pools,
    }

    init_data(::LoadBalancerListenerPool, attributes, extra_attributes)
  end

  def load_balancer_health_checks_init_data(extra_attributes = {})
    attributes = {
      :association => :load_balancer_health_checks,
    }

    init_data(::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerHealthCheck, attributes, extra_attributes)
  end

  def load_balancer_health_check_members_init_data(extra_attributes = {})
    attributes = {
      :manager_ref => [:load_balancer_health_check, :load_balancer_pool_member],
      :association => :load_balancer_health_check_members,
    }

    init_data(::LoadBalancerHealthCheckMember, attributes, extra_attributes)
  end
end
