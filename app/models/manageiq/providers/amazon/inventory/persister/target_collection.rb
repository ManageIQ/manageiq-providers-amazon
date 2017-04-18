class ManageIQ::Providers::Amazon::Inventory::Persister::TargetCollection < ManageIQ::Providers::Amazon::Inventory::Persister
  def initialize_inventory_collections
    add_targeted_inventory_collections
    add_remaining_inventory_collections([cloud, network, storage], :strategy => :local_db_find_references)

    add_inventory_collection(
      cloud.vm_and_miq_template_ancestry(
        :dependency_attributes => {
          :vms           => [collections[:vms]],
          :miq_templates => [collections[:miq_templates]]
        }
      )
    )

    add_inventory_collection(
      cloud.orchestration_stack_ancestry(
        :dependency_attributes => {
          :orchestration_stacks           => [collections[:orchestration_stacks]],
          :orchestration_stacks_resources => [collections[:orchestration_stacks_resources]]
        }
      )
    )
  end

  private

  def references(collection)
    target.manager_refs_by_association.try(:[], collection).try(:[], :ems_ref).try(:to_a) || []
  end

  def name_references(collection)
    target.manager_refs_by_association.try(:[], collection).try(:[], :name).try(:to_a) || []
  end

  def cloud
    ManageIQ::Providers::Amazon::InventoryCollectionDefault::CloudManager
  end

  def network
    ManageIQ::Providers::Amazon::InventoryCollectionDefault::NetworkManager
  end

  def storage
    ManageIQ::Providers::Amazon::InventoryCollectionDefault::StorageManager
  end

  def add_targeted_inventory_collections
    # Cloud
    add_vms_inventory_collections(references(:vms))
    add_miq_templates_inventory_collections(references(:miq_templates))
    add_vms_and_miq_templates_inventory_collections(references(:vms) + references(:miq_templates))
    add_key_pairs_inventory_collections(name_references(:key_pairs))
    add_availability_zones_inventory_collections(references(:availability_zones))
    add_stacks_inventory_collections(references(:orchestration_stacks))

    # Network
    add_cloud_networks_inventory_collections(references(:cloud_networks))
    add_cloud_subnets_inventory_collections(references(:cloud_subnets))
    add_network_ports_inventory_collections(references(:vms) + references(:network_ports))
    add_security_groups_inventory_collections(references(:security_groups))
    add_floating_ips_inventory_collections(references(:floating_ips))
    add_load_balancers_collections(references(:load_balancers))

    # Storage
    add_cloud_volumes_collections(references(:cloud_volumes))
    add_cloud_volume_snapshots_collections(references(:cloud_volume_snapshots))
  end

  def add_vms_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      cloud.vms(
        :arel     => manager.vms.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )
    add_inventory_collection(
      cloud.disks(
        :arel     => manager.disks.joins(:hardware => :vm_or_template).where(
          :hardware => {'vms' => {:ems_ref => manager_refs}}
        ),
        :strategy => :local_db_find_missing_references
      )
    )
    add_inventory_collection(
      cloud.networks(
        :arel     => manager.networks.joins(:hardware => :vm_or_template).where(
          :hardware => {'vms' => {:ems_ref => manager_refs}}
        ),
        :strategy => :local_db_find_missing_references
      )
    )
  end

  def add_key_pairs_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      cloud.key_pairs(
        :arel     => manager.key_pairs.where(:name => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )
  end

  def add_availability_zones_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      cloud.availability_zones(
        :arel     => manager.availability_zones.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )
  end

  def add_miq_templates_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      cloud.miq_templates(
        :arel     => manager.miq_templates.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )
  end

  def add_vms_and_miq_templates_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      cloud.hardwares(
        :arel     => manager.hardwares.joins(:vm_or_template).where(
          'vms' => {:ems_ref => manager_refs}
        ),
        :strategy => :local_db_find_missing_references
      )
    )
    add_inventory_collection(
      cloud.vm_and_template_labels(
        :arel     => manager.vm_and_template_labels.where(
          'vms' => {:ems_ref => manager_refs}
        ),
        :strategy => :local_db_find_missing_references
      )
    )
  end

  def add_stacks_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      cloud.orchestration_stacks(
        :arel     => manager.orchestration_stacks.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )

    add_inventory_collection(
      cloud.orchestration_stacks_resources(
        :arel     => manager.orchestration_stacks_resources.references(:orchestration_stacks).where(
          :orchestration_stacks => {:ems_ref => manager_refs}
        ),
        :strategy => :local_db_find_missing_references
      )
    )

    add_inventory_collection(
      cloud.orchestration_stacks_outputs(
        :arel     => manager.orchestration_stacks_outputs.references(:orchestration_stacks).where(
          :orchestration_stacks => {:ems_ref => manager_refs}
        ),
        :strategy => :local_db_find_missing_references
      )
    )

    add_inventory_collection(
      cloud.orchestration_stacks_parameters(
        :arel     => manager.orchestration_stacks_parameters.references(:orchestration_stacks).where(
          :orchestration_stacks => {:ems_ref => manager_refs}
        ),
        :strategy => :local_db_find_missing_references
      )
    )

    add_inventory_collection(cloud.orchestration_templates)
  end

  def add_cloud_networks_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      network.cloud_networks(
        :arel     => manager.network_manager.cloud_networks.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )
  end

  def add_cloud_subnets_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      network.cloud_subnets(
        :arel     => manager.network_manager.cloud_subnets.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )
  end

  def add_security_groups_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      network.security_groups(
        :arel     => manager.network_manager.security_groups.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )
    add_inventory_collection(
      network.firewall_rules(
        :arel     => manager.network_manager.firewall_rules.references(:security_groups).where(
          :security_groups => {:ems_ref => manager_refs}
        ),
        :strategy => :local_db_find_missing_references
      )
    )
  end

  def add_network_ports_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      network.network_ports(
        :arel     => manager.network_manager.network_ports.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )
    add_inventory_collection(
      network.cloud_subnet_network_ports(
        :arel     => manager.network_manager.cloud_subnet_network_ports.references(:network_ports).where(
          :network_ports => {:ems_ref => manager_refs}
        ),
        :strategy => :local_db_find_missing_references
      )
    )
  end

  def add_floating_ips_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      network.floating_ips(
        :arel     => manager.network_manager.floating_ips.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )
  end

  def add_load_balancers_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      network.load_balancers(
        :arel     => manager.network_manager.load_balancers.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )

    add_inventory_collection(
      network.load_balancer_health_checks(
        :arel     => manager.network_manager.load_balancer_health_checks.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )

    add_inventory_collection(
      network.load_balancer_health_check_members(
        :arel     => manager.network_manager.load_balancer_health_check_members.references(:load_balancer_health_checks).where(
          :load_balancer_health_checks => {:ems_ref => manager_refs}
        ),
        :strategy => :local_db_find_missing_references
      )
    )

    add_inventory_collection(
      network.load_balancer_listeners(
        :arel     => manager.network_manager.load_balancer_listeners.joins(:load_balancer).where(
          :load_balancers => {:ems_ref => manager_refs}
        ),
        :strategy => :local_db_find_missing_references
      )
    )

    add_inventory_collection(
      network.load_balancer_listener_pools(
        :arel     => manager.network_manager.load_balancer_listener_pools.joins(:load_balancer_pool).where(
          :load_balancer_pools => {:ems_ref => manager_refs}
        ),
        :strategy => :local_db_find_missing_references
      )
    )

    add_inventory_collection(
      network.load_balancer_pools(
        :arel     => manager.network_manager.load_balancer_pools.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )

    add_inventory_collection(
      network.load_balancer_pool_member_pools(
        :arel     => manager.network_manager.load_balancer_pool_member_pools
                       .references(:load_balancer_pools)
                       .where(:load_balancer_pools => {:ems_ref => manager_refs})
                       .distinct,
        :strategy => :local_db_find_missing_references
      )
    )

    add_inventory_collection(
      network.load_balancer_pool_members(
        :arel     => manager.network_manager.load_balancer_pool_members
                       .joins(:load_balancer_pool_member_pools => :load_balancer_pool)
                       .where(:load_balancer_pool_member_pools => {'load_balancer_pools' => {:ems_ref => manager_refs}})
                       .distinct,
        :strategy => :local_db_find_missing_references
      )
    )
  end

  def add_cloud_volumes_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      storage.cloud_volumes(
        :arel     => manager.ebs_storage_manager.cloud_volumes.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )
  end

  def add_cloud_volume_snapshots_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      storage.cloud_volume_snapshots(
        :arel     => manager.ebs_storage_manager.cloud_volume_snapshots.where(:ems_ref => manager_refs),
        :strategy => :local_db_find_missing_references
      )
    )
  end
end
