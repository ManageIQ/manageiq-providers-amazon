class ManageIQ::Providers::Amazon::Inventory::Targets::TargetCollection < ManageIQ::Providers::Amazon::Inventory::Targets
  def initialize_collector
    ManageIQ::Providers::Amazon::Inventory::Collectors::TargetCollection.new(ems, target)
  end

  def initialize_inventory_collections
    add_targeted_inventory_collections
    add_remaining_inventory_collections(:strategy => :local_db_find_one)

    vm_and_miq_template_ancestry_save_block = lambda do |_ems, inventory_collection|
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

    add_inventory_collection(
      [
        ManageIQ::Providers::Amazon::CloudManager::Vm,
        :custom_save_block     => vm_and_miq_template_ancestry_save_block,
        :dependency_attributes => {:vms           => [inventory_collections[:vms]],
                                   :miq_templates => [inventory_collections[:miq_templates]]}],
      :vm_and_miq_template_ancestry)

    orchestration_stack_ancestry_save_block = lambda do |_ems, inventory_collection|
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

    add_inventory_collection(
      [
        ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack,
        :custom_save_block     => orchestration_stack_ancestry_save_block,
        :dependency_attributes => {:orchestration_stacks           => [inventory_collections[:orchestration_stacks]],
                                   :orchestration_stacks_resources => [inventory_collections[:orchestration_stacks_resources]]}],
      :orchestration_stack_ancestry)
  end

  private

  def add_targeted_inventory_collections
    images_refs = collector.private_images_refs.to_a + collector.shared_images_refs.to_a + collector.public_images_refs.to_a

    # Cloud
    add_vms_inventory_collections(collector.instances_refs.to_a)
    add_miq_templates_inventory_collections(images_refs)
    add_hardwares_inventory_collections(collector.instances_refs.to_a + images_refs)
    add_stacks_inventory_collections(collector.stacks_refs.to_a)

    # Network
    add_cloud_networks_inventory_collections(collector.cloud_networks_refs.to_a)
    add_cloud_subnets_inventory_collections(collector.cloud_subnets_refs.to_a)
    add_network_ports_inventory_collections(collector.instances_refs.to_a + collector.network_ports_refs.to_a)
    add_security_groups_inventory_collections(collector.security_groups_refs.to_a)
    add_floating_ips_inventory_collections(collector.floating_ips_refs.to_a)
    add_load_balancers_collections(collector.load_balancers_refs.to_a)

    # Storage
    add_cloud_volumes_collections(collector.cloud_volumes_refs.to_a)
    add_cloud_volume_snapshots_collections(collector.cloud_volume_snapshots_refs.to_a)
  end

  def add_vms_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      vms_init_data(
        :arel     => ems.vms.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
    add_inventory_collection(
      disks_init_data(
        :arel     => ems.disks.joins(:hardware => :vm_or_template).where(
          :hardware => {'vms' => {:ems_ref => manager_refs}}),
        :strategy => :find_missing_in_local_db))
    add_inventory_collection(
      networks_init_data(
        :arel     => ems.networks.joins(:hardware => :vm_or_template).where(
          :hardware => {'vms' => {:ems_ref => manager_refs}}),
        :strategy => :find_missing_in_local_db))
  end

  def add_miq_templates_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      miq_templates_init_data(
        :arel     => ems.miq_templates.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
  end

  def add_hardwares_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      hardwares_init_data(
        :arel     => ems.hardwares.joins(:vm_or_template).where(
          'vms' => {:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))
  end

  def add_stacks_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      orchestration_stacks_init_data(
        :arel     => ems.orchestration_stacks.where({:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))

    add_inventory_collection(
      orchestration_stacks_resources_init_data(
        :arel     => ems.orchestration_stacks_resources.references(:orchestration_stacks).where(
          :orchestration_stacks => {:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))

    add_inventory_collection(
      orchestration_stacks_outputs_init_data(
        :arel     => ems.orchestration_stacks_outputs.references(:orchestration_stacks).where(
          :orchestration_stacks => {:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))

    add_inventory_collection(
      orchestration_stacks_parameters_init_data(
        :arel     => ems.orchestration_stacks_parameters.references(:orchestration_stacks).where(
          :orchestration_stacks => {:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))

    add_inventory_collection(orchestration_templates_init_data)
  end

  def add_cloud_networks_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      cloud_networks_init_data(
        :arel     => ems.network_manager.cloud_networks.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
  end

  def add_cloud_subnets_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      cloud_subnets_init_data(
        :arel     => ems.network_manager.cloud_subnets.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
  end

  def add_security_groups_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      security_groups_init_data(
        :arel     => ems.network_manager.security_groups.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
    add_inventory_collection(
      firewall_rules_init_data(
        :arel     => ems.network_manager.firewall_rules.references(:security_groups).where(
          :security_groups => {:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))
  end

  def add_network_ports_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      network_ports_init_data(
        :arel     => ems.network_manager.network_ports.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
    add_inventory_collection(
      cloud_subnet_network_ports_init_data(
        :arel     => ems.network_manager.cloud_subnet_network_ports.references(:network_ports).where(
          :network_ports => {:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))
  end

  def add_floating_ips_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      floating_ips_init_data(
        :arel     => ems.network_manager.floating_ips.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
  end

  def add_load_balancers_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      load_balancers_init_data(
        :arel     => ems.network_manager.load_balancers.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))

    add_inventory_collection(
      load_balancer_health_checks_init_data(
        :arel     => ems.network_manager.load_balancer_health_checks.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))

    add_inventory_collection(
      load_balancer_health_check_members_init_data(
        :arel     => ems.network_manager.load_balancer_health_check_members.references(:load_balancer_health_checks).where(
          :load_balancer_health_checks => {:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))

    add_inventory_collection(
      load_balancer_listeners_init_data(
        :arel     => ems.network_manager.load_balancer_listeners.joins(:load_balancer).where(
          :load_balancers => {:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))

    add_inventory_collection(
      load_balancer_listener_pools_init_data(
        :arel     => ems.network_manager.load_balancer_listener_pools.joins(:load_balancer_pool).where(
          :load_balancer_pools => {:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))

    add_inventory_collection(
      load_balancer_pools_init_data(
        :arel     => ems.network_manager.load_balancer_pools.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))

    add_inventory_collection(
      load_balancer_pool_member_pools_init_data(
        :arel     => ems.network_manager.load_balancer_pool_member_pools.references(:load_balancer_pools).where(:load_balancer_pools => {:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))

    add_inventory_collection(
      load_balancer_pool_members_init_data(
        :arel     => ems.network_manager.load_balancer_pool_members.joins(:load_balancer_pool_member_pools => :load_balancer_pool).where(:load_balancer_pool_member_pools => {'load_balancer_pools' => {:ems_ref => manager_refs}}),
        :strategy => :find_missing_in_local_db))
  end

  def add_cloud_volumes_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      cloud_volumes_init_data(
        :arel     => ems.ebs_storage_manager.cloud_volumes.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
  end

  def add_cloud_volume_snapshots_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      cloud_volume_snapshots_init_data(
        :arel     => ems.ebs_storage_manager.cloud_volume_snapshots.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
  end
end
