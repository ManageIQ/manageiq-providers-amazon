class ManageIQ::Providers::Amazon::Inventory::Persister::TargetCollection < ManageIQ::Providers::Amazon::Inventory::Persister
  def initialize_inventory_collections
    ######### Cloud ##########
    # Top level models with direct references for Cloud
    add_inventory_collections_with_references(
      cloud,
      %i(vms miq_templates availability_zones orchestration_stacks)
    )

    add_inventory_collection_with_references(
      cloud,
      :key_pairs,
      name_references(:key_pairs)
    )

    # Child models with references in the Parent InventoryCollections for Cloud
    add_inventory_collections(
      cloud,
      %i(hardwares operating_systems networks disks vm_and_template_labels vm_and_template_taggings
         orchestration_stacks_resources orchestration_stacks_outputs orchestration_stacks_parameters)
    )

    add_inventory_collection(cloud.orchestration_templates)

    ######### Network ################
    # Top level models with direct references for Network
    add_inventory_collections_with_references(
      network,
      %i(cloud_networks cloud_subnets security_groups load_balancers),
      :parent => manager.network_manager
    )

    add_inventory_collection_with_references(
      network,
      :network_ports,
      references(:vms) + references(:network_ports) + references(:load_balancers),
      :parent => manager.network_manager
    )

    add_inventory_collection_with_references(
      network,
      :floating_ips,
      references(:floating_ips) + references(:load_balancers),
      :parent => manager.network_manager
    )

    # Child models with references in the Parent InventoryCollections for Network
    add_inventory_collections(
      network,
      %i(firewall_rules cloud_subnet_network_ports load_balancer_pools load_balancer_pool_members
         load_balancer_pool_member_pools load_balancer_listeners load_balancer_listener_pools
         load_balancer_health_checks load_balancer_health_check_members),
      :parent   => manager.network_manager
    )

    ######### Storage ##############
    # Top level models with direct references for Network
    add_inventory_collections_with_references(
      storage,
      %i(cloud_volumes cloud_volume_snapshots),
      :parent => manager.ebs_storage_manager
    )

    if manager.s3_storage_manager
      add_inventory_collections_with_references(
        storage,
        %i(cloud_object_store_containers cloud_object_store_objects),
        :parent => manager.s3_storage_manager
      )
    end

    # Model we take just from a DB, there is no flavors API
    add_inventory_collections(
      cloud,
      %i(flavors),
      :strategy => :local_db_find_references
    )

    ######## Custom processing of Ancestry ##########
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

  def add_inventory_collections_with_references(inventory_collections_data, names, options = {})
    names.each do |name|
      add_inventory_collection_with_references(inventory_collections_data, name, references(name), options)
    end
  end

  def add_inventory_collection_with_references(inventory_collections_data, name, manager_refs, options = {})
    options = shared_options.merge(inventory_collections_data.send(
      name,
      :manager_uuids => manager_refs,
    ).merge(options))

    add_inventory_collection(options)
  end

  def targeted
    true
  end

  def strategy
    :local_db_find_missing_references
  end

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
end
