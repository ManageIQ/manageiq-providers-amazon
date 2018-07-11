module ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::CloudCollections
  extend ActiveSupport::Concern

  def initialize_cloud_inventory_collections
    %i(availability_zones
       disks
       hardwares
       networks
       operating_systems
       vm_and_template_labels
       vm_and_template_taggings
       vms).each do |name|

      add_collection(cloud, name)
    end

    add_miq_templates

    add_flavors

    add_key_pairs

    %i(orchestration_stacks
       orchestration_stacks_resources
       orchestration_stacks_outputs
       orchestration_stacks_parameters
       orchestration_templates).each do |name|

      add_collection(cloud, name)
    end

    # Custom processing of Ancestry
    %i(vm_and_miq_template_ancestry
       orchestration_stack_ancestry).each do |name|

      add_collection(cloud, name)
    end
  end

  # ------ IC provider specific definitions -------------------------

  def add_miq_templates(extra_properties = {})
    add_collection(cloud, :miq_templates, extra_properties) do |builder|
      builder.add_properties(:model_class => ::ManageIQ::Providers::Amazon::CloudManager::Template)
    end
  end

  def add_flavors(extra_properties = {})
    add_collection(cloud, :flavors, extra_properties) do |builder|
      # Model we take just from a DB, there is no flavors API
      builder.add_properties(:strategy => :local_db_find_references) if targeted?
    end
  end

  def add_key_pairs(extra_properties = {})
    add_collection(cloud, :key_pairs, extra_properties) do |builder|
      builder.add_properties(:model_class => ::ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair)
      builder.add_properties(:manager_uuids => name_references(:key_pairs)) if targeted?
    end
  end
end
