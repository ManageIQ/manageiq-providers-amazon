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
        :model_class => ::ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone,
      }

      super(attributes.merge!(extra_attributes))
    end

    def flavors(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::CloudManager::Flavor,
      }

      super(attributes.merge!(extra_attributes))
    end

    def key_pairs(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair,
      }

      super(attributes.merge!(extra_attributes))
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
