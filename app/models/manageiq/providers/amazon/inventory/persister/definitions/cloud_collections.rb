module ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::CloudCollections
  extend ActiveSupport::Concern

  def initialize_cloud_inventory_collections
    %i(auth_key_pairs
       availability_zones
       disks
       flavors
       hardwares
       networks
       operating_systems
       vm_and_template_labels
       vm_and_template_taggings
       vms
       miq_templates
       cloud_databases
       service_instances
       service_offerings
       service_parameters_sets).each do |name|

      add_cloud_collection(name)
    end

    add_cloud_database_flavors

    %i(orchestration_stacks
       orchestration_stacks_resources
       orchestration_stacks_outputs
       orchestration_stacks_parameters
       orchestration_templates).each do |name|

      add_cloud_collection(name)
    end

    # Custom processing of Ancestry
    %i(vm_and_miq_template_ancestry
       orchestration_stack_ancestry).each do |name|

      add_cloud_collection(name)
    end
  end

  # ------ IC provider specific definitions -------------------------

  def add_cloud_database_flavors(extra_properties = {})
    add_cloud_collection(:cloud_database_flavors, extra_properties) do |builder|
      # Model we take just from a DB, there is no flavors API
      builder.add_properties(:strategy => :local_db_find_references) if targeted?
    end
  end
end
