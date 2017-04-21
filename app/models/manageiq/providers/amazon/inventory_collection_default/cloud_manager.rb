class ManageIQ::Providers::Amazon::InventoryCollectionDefault::CloudManager < ManagerRefresh::InventoryCollectionDefault::CloudManager
  class << self
    def vms(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::CloudManager::Vm,
      }
      super(attributes.merge!(extra_attributes))
    end

    def miq_templates(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::CloudManager::Template,
      }

      super(attributes.merge!(extra_attributes))
    end

    def availability_zones(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone,
        :inventory_object_attributes => [
          :type,
          :ext_management_system,
          :ems_ref,
          :name,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def flavors(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::CloudManager::Flavor,
        :inventory_object_attributes => [
          :type,
          :ext_management_system,
          :ems_ref,
          :name,
          :description,
          :enabled,
          :cpus,
          :cpu_cores,
          :memory,
          :supports_32_bit,
          :supports_64_bit,
          :supports_hvm,
          :supports_paravirtual,
          :block_storage_based_only,
          :cloud_subnet_required,
          :ephemeral_disk_size,
          :ephemeral_disk_count,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def key_pairs(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair,
        :inventory_object_attributes => [
          :type,
          :resource,
          :name,
          :fingerprint,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def vm_and_template_labels(extra_attributes = {})
      attributes = {
        :model_class => CustomAttribute,
        :association => :vm_and_template_labels,
        :manager_ref => [:resource, :name]
      }

      attributes.merge!(extra_attributes)
    end

    def orchestration_stacks(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack,
      }

      super(attributes.merge!(extra_attributes))
    end

    def orchestration_templates(extra_attributes = {})
      attributes = {
        :model_class => ::OrchestrationTemplateCfn,
      }

      super(attributes.merge!(extra_attributes))
    end

    def disks(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => %i(hardware device_name location size backing),
      }

      super(attributes.merge!(extra_attributes))
    end
  end
end
