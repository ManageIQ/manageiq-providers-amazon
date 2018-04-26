class ManageIQ::Providers::Amazon::Inventory::Persister::TargetCollection < ManageIQ::Providers::Amazon::Inventory::Persister
  include ManageIQ::Providers::Amazon::Inventory::Persister::Shared::CloudCollections
  include ManageIQ::Providers::Amazon::Inventory::Persister::Shared::NetworkCollections
  include ManageIQ::Providers::Amazon::Inventory::Persister::Shared::StorageCollections

  def targeted
    true
  end

  def strategy
    :local_db_find_missing_references
  end

  def initialize_inventory_collections
    initialize_tag_mapper

    initialize_cloud_inventory_collections

    initialize_network_inventory_collections

    initialize_storage_inventory_collections
  end

  private

  def initialize_cloud_inventory_collections
    init_cloud_ics_top_level_models

    init_cloud_ics_child_models

    # Custom processing of Ancestry
    add_vm_and_miq_template_ancestry

    add_orchestration_stack_ancestry
  end

  # Top level models with direct references for Cloud
  def init_cloud_ics_top_level_models
    %i(vms availability_zones).each do |name|
      add_collection(cloud, name, :manager_uuids => references(name))
    end

    add_miq_templates(:manager_uuids => references(:miq_templates))

    add_orchestration_stacks(:manager_uuids => references(:orchestration_stacks))

    add_key_pairs(:manager_uuids => name_references(:key_pairs))
  end

  # Child models with references in the Parent InventoryCollections for Cloud
  def init_cloud_ics_child_models
    %i(hardwares
       operating_systems
       networks
       disks
       orchestration_stacks_resources
       orchestration_stacks_outputs
       orchestration_stacks_parameters
       orchestration_templates).each do |name|

      add_collection(cloud, name)
    end

    add_vm_and_template_labels

    add_vm_and_template_taggings

    # Model we take just from a DB, there is no flavors API
    add_flavors(:strategy => :local_db_find_references)
  end

  def initialize_network_inventory_collections
    initialize_network_ics_top_level_models

    initialize_network_ics_child_models
  end

  # Top level models with direct references for Network
  def initialize_network_ics_top_level_models
    %i(cloud_networks
       cloud_subnets
       security_groups
       load_balancers).each do |name|

      add_collection(network, name, :manager_uuids => references(name)) do |builder|
        builder.add_properties(:parent => manager.network_manager)
      end
    end

    add_collection(network, :network_ports, :manager_uuids => references(:vms) + references(:network_ports) + references(:load_balancers)) do |builder|
      builder.add_properties(:parent => manager.network_manager)
    end

    add_collection(network, :floating_ips, :manager_uuids => references(:floating_ips) + references(:load_balancers)) do |builder|
      builder.add_properties(:parent => manager.network_manager)
    end
  end

  # Child models with references in the Parent InventoryCollections for Network
  def initialize_network_ics_child_models
    add_firewall_rules(:parent => manager.network_manager)

    add_cloud_subnet_network_ports(:parent => manager.network_manager)

    %i(load_balancer_pools
       load_balancer_pool_members
       load_balancer_pool_member_pools
       load_balancer_listeners
       load_balancer_listener_pools
       load_balancer_health_checks
       load_balancer_health_check_members).each do |name|

      add_collection(network, name) do |builder|
        builder.add_properties(:parent => manager.network_manager)
      end
    end
  end

  # Top level models with direct references for Network
  def initialize_storage_inventory_collections
    add_cloud_volumes(:manager_uuids => references(:cloud_volumes)) do |builder|
      builder.add_properties(:parent => manager.ebs_storage_manager)
    end

    add_cloud_volume_snapshots(:manager_uuids => references(:cloud_volume_snapshots)) do |builder|
      builder.add_properties(:parent => manager.ebs_storage_manager)
    end

    if manager.s3_storage_manager

      add_cloud_object_store_containers(:manager_uuids => references(:cloud_object_store_containers)) do |builder|
        builder.add_properties(:parent => manager.s3_storage_manager)
      end

      add_cloud_object_store_objects(:manager_uuids => references(:cloud_object_store_objects)) do |builder|
        builder.add_properties(:parent => manager.s3_storage_manager)
      end
    end
  end

  def references(collection)
    target.manager_refs_by_association.try(:[], collection).try(:[], :ems_ref).try(:to_a) || []
  end

  def name_references(collection)
    target.manager_refs_by_association.try(:[], collection).try(:[], :name).try(:to_a) || []
  end
end
