module ManageIQ::Providers::Amazon::Inventory::InventoryCollectionDefaultInitData
  def init_data(attributes, extra_attributes)
    init_data = {
      :delete_method => attributes[:model_class].new.respond_to?(:disconnect_inv) ? :disconnect_inv : nil
    }

    init_data.merge!(attributes).merge!(extra_attributes)
    return init_data
  end

  def vms_init_data(extra_attributes = {})
    attributes = {
      :model_class          => ::ManageIQ::Providers::Amazon::CloudManager::Vm,
      :association          => :vms,
      :attributes_blacklist => [:genealogy_parent]
    }

    init_data(attributes, extra_attributes)
  end

  def miq_templates_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::CloudManager::Template,
      :association => :miq_templates,
    }

    init_data(attributes, extra_attributes)
  end

  def availability_zones_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone,
      :association => :availability_zones,
    }

    init_data(attributes, extra_attributes)
  end

  def flavors_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::CloudManager::Flavor,
      :association => :flavors,
    }

    init_data(attributes, extra_attributes)
  end

  def key_pairs_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair,
      :manager_ref => [:name],
      :association => :key_pairs
    }

    init_data(attributes, extra_attributes)
  end

  def hardwares_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::Hardware,
      :manager_ref => [:vm_or_template],
      :association => :hardwares
    }

    case extra_attributes[:strategy]
    when :local_db_cache_all
      attributes[:custom_manager_uuid] = lambda do |hardware|
        [hardware.vm_or_template.ems_ref]
      end
    when :find_missing_in_local_db
      attributes[:custom_db_finder] = lambda do |inventory_collection, hash_uuid_by_ref|
        inventory_collection.parent.send(inventory_collection.association).references(:vm_or_template).where(
          :vms => {:ems_ref => hash_uuid_by_ref[:vm_or_template]}
        ).first
      end
    end

    init_data(attributes, extra_attributes)
  end

  def disks_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::Disk,
      :manager_ref => [:hardware, :device_name],
      :association => :disks
    }

    if extra_attributes[:strategy] == :local_db_cache_all
      attributes[:custom_manager_uuid] = lambda do |disk|
        [disk.hardware.vm_or_template.ems_ref, disk.device_name]
      end
    end

    init_data(attributes, extra_attributes)
  end

  def networks_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::Network,
      :manager_ref => [:hardware, :description],
      :association => :networks
    }

    if extra_attributes[:strategy] == :local_db_cache_all
      attributes[:custom_manager_uuid] = lambda do |network|
        [network.hardware.vm_or_template.ems_ref, network.description]
      end
    end

    init_data(attributes, extra_attributes)
  end

  def orchestration_stacks_init_data(extra_attributes = {})
    attributes = {
      :model_class          => ::ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack,
      :association          => :orchestration_stacks,
      :attributes_blacklist => [:parent]
    }

    init_data(attributes, extra_attributes)
  end

  def orchestration_stacks_resources_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::OrchestrationStackResource,
      :association => :orchestration_stacks_resources,
    }

    init_data(attributes, extra_attributes)
  end

  def orchestration_stacks_outputs_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::OrchestrationStackOutput,
      :association => :orchestration_stacks_outputs,
    }

    init_data(attributes, extra_attributes)
  end

  def orchestration_stacks_parameters_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::OrchestrationStackParameter,
      :association => :orchestration_stacks_parameters,
    }

    init_data(attributes, extra_attributes)
  end

  def orchestration_templates_init_data(extra_attributes = {})
    # TODO(lsmola) do refactoring, we shouldn't need this custom saving block
    orchestration_template_save_block = lambda do |_ems, inventory_collection|
      hashes = inventory_collection.data.map(&:attributes)

      templates = ::OrchestrationTemplate.find_or_create_by_contents(hashes)
      inventory_collection.data.zip(templates).each do |inventory_object, template|
        inventory_object.id = template.id
      end
    end

    attributes = {
      :model_class       => ::OrchestrationTemplateCfn,
      :association       => :orchestration_templates,
      :custom_save_block => orchestration_template_save_block
    }

    init_data(attributes, extra_attributes)
  end

  def cloud_subnet_network_ports_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::CloudSubnetNetworkPort,
      :manager_ref => [:address, :cloud_subnet, :network_port],
      :association => :cloud_subnet_network_ports,
    }

    init_data(attributes, extra_attributes)
  end

  def network_ports_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::NetworkPort,
      :association => :network_ports,
    }

    init_data(attributes, extra_attributes)
  end

  def floating_ips_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::FloatingIp,
      :association => :floating_ips,
    }

    init_data(attributes, extra_attributes)
  end

  def cloud_subnets_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet,
      :association => :cloud_subnets,
    }

    init_data(attributes, extra_attributes)
  end

  def cloud_networks_init_data(extra_attributes = {})
    attributes = {
      :model_class => ManageIQ::Providers::Amazon::NetworkManager::CloudNetwork,
      :association => :cloud_networks,
    }

    init_data(attributes, extra_attributes)
  end

  def security_groups_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup,
      :association => :security_groups,
    }

    init_data(attributes, extra_attributes)
  end

  def firewall_rules_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::FirewallRule,
      :manager_ref => [:resource, :source_security_group, :direction, :host_protocol, :port, :end_port, :source_ip_range],
      :association => :firewall_rules,
    }

    init_data(attributes, extra_attributes)
  end

  def load_balancers_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer,
      :association => :load_balancers,
    }

    init_data(attributes, extra_attributes)
  end

  def load_balancer_pools_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPool,
      :association => :load_balancer_pools,
    }

    init_data(attributes, extra_attributes)
  end

  def load_balancer_pool_members_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPoolMember,
      :association => :load_balancer_pool_members,
    }

    init_data(attributes, extra_attributes)
  end

  def load_balancer_pool_member_pools_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::LoadBalancerPoolMemberPool,
      :manager_ref => [:load_balancer_pool, :load_balancer_pool_member],
      :association => :load_balancer_pool_member_pools,
    }

    init_data(attributes, extra_attributes)
  end

  def load_balancer_listeners_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener,
      :association => :load_balancer_listeners,
    }

    init_data(attributes, extra_attributes)
  end

  def load_balancer_listener_pools_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::LoadBalancerListenerPool,
      :manager_ref => [:load_balancer_listener, :load_balancer_pool],
      :association => :load_balancer_listener_pools,
    }

    init_data(attributes, extra_attributes)
  end

  def load_balancer_health_checks_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerHealthCheck,
      :association => :load_balancer_health_checks,
    }

    init_data(attributes, extra_attributes)
  end

  def load_balancer_health_check_members_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::LoadBalancerHealthCheckMember,
      :manager_ref => [:load_balancer_health_check, :load_balancer_pool_member],
      :association => :load_balancer_health_check_members,
    }

    init_data(attributes, extra_attributes)
  end

  def cloud_volumes_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume,
      :association => :cloud_volumes,
    }

    init_data(attributes, extra_attributes)
  end

  def cloud_volume_snapshots_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot,
      :association => :cloud_volume_snapshots,
    }

    init_data(attributes, extra_attributes)
  end

  def cloud_object_store_containers_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::CloudObjectStoreContainer,
      :association => :cloud_object_store_containers,
    }

    init_data(attributes, extra_attributes)
  end

  def cloud_object_store_objects_init_data(extra_attributes = {})
    attributes = {
      :model_class => ::CloudObjectStoreObject,
      :association => :cloud_object_store_objects,
    }

    init_data(attributes, extra_attributes)
  end

  def orchestration_stack_ancestry_init_data(extra_attributes = {})
    orchestration_stack_ancestry_save_block = lambda do |_ems, inventory_collection|
      return if inventory_collection.dependency_attributes[:orchestration_stacks].blank?

      stacks_parents = inventory_collection.dependency_attributes[:orchestration_stacks].first.data.each_with_object({}) do |x, obj|
        parent_id = x.data[:parent].load.try(:id)
        obj[x.id] = parent_id if parent_id
      end

      stacks_parents_indexed = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack
                                 .select([:id, :ancestry])
                                 .where(:id => stacks_parents.values).find_each.index_by(&:id)

      ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack
        .select([:id, :ancestry])
        .where(:id => stacks_parents.keys).find_each do |stack|
        parent = stacks_parents_indexed[stacks_parents[stack.id]]
        stack.update_attribute(:parent, parent)
      end
    end

    attributes = {
      :association       => :orchestration_stack_ancestry,
      :custom_save_block => orchestration_stack_ancestry_save_block
    }
    attributes.merge!(extra_attributes)
    attributes
  end

  def vm_and_miq_template_ancestry_init_data(extra_attributes = {})
    vm_and_miq_template_ancestry_save_block = lambda do |_ems, inventory_collection|
      return if inventory_collection.dependency_attributes[:vms].blank?

      # Fetch IDs of all vms and genealogy_parents, only if genealogy_parent is present
      vms_genealogy_parents = inventory_collection.dependency_attributes[:vms].first.data.each_with_object({}) do |x, obj|
        genealogy_parent_id = x.data[:genealogy_parent].load.try(:id)
        obj[x.id]           = genealogy_parent_id if genealogy_parent_id
      end

      miq_templates = ManageIQ::Providers::Amazon::CloudManager::Template
                        .select([:id])
                        .where(:id => vms_genealogy_parents.values).find_each.index_by(&:id)

      ManageIQ::Providers::Amazon::CloudManager::Vm
        .select([:id])
        .where(:id => vms_genealogy_parents.keys).find_each do |vm|
        parent = miq_templates[vms_genealogy_parents[vm.id]]
        parent.with_relationship_type('genealogy') { parent.set_child(vm) }
      end
    end

    attributes = {
      :association       => :vm_and_miq_template_ancestry,
      :custom_save_block => vm_and_miq_template_ancestry_save_block,
    }
    attributes.merge!(extra_attributes)
    attributes
  end
end
