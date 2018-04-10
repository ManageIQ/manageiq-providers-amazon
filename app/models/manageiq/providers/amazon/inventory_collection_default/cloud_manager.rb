class ManageIQ::Providers::Amazon::InventoryCollectionDefault::CloudManager < ManagerRefresh::InventoryCollectionDefault::CloudManager
  class << self
    def vms(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::CloudManager::Vm,
        :inventory_object_attributes => [
          :type,
          :ext_management_system,
          :uid_ems,
          :ems_ref,
          :name,
          :vendor,
          :raw_power_state,
          :boot_time,
          :availability_zone,
          :flavor,
          :genealogy_parent,
          :key_pairs,
          :location,
          :orchestration_stack,
        ]
      }
      super(attributes.merge!(extra_attributes))
    end

    def miq_templates(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::CloudManager::Template,
        :inventory_object_attributes => [
          :type,
          :ext_management_system,
          :uid_ems,
          :ems_ref,
          :name,
          :location,
          :vendor,
          :raw_power_state,
          :template,
          :publicly_available,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def hardwares(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :guest_os,
          :bitness,
          :virtualization_type,
          :root_device_type,
          :vm_or_template,
          :root_device_type,
          :cpu_sockets,
          :cpu_cores_per_socket,
          :cpu_total_cores,
          :memory_mb,
          :disk_capacity,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def networks(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :hardware,
          :ipaddress,
          :hostname,
          :description,
        ]
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
        :model_class                 => CustomAttribute,
        :association                 => :vm_and_template_labels,
        :manager_ref                 => [:resource, :name],
        :inventory_object_attributes => [
          :resource,
          :section,
          :name,
          :value,
          :source,
        ]
      }

      attributes.merge!(extra_attributes)
    end

    def vm_and_template_taggings(extra_attributes = {})
      # TODO: make a generic Taggings IC and move it to base class?
      attributes = {
        :model_class                  => Tagging,
        :association                  => :vm_and_template_taggings,
        :manager_ref                  => [:taggable, :tag],
        :parent_inventory_collections => [:vms, :miq_templates],
        :inventory_object_attributes  => [
          :taggable,
          :tag,
        ]
      }

      attributes[:targeted_arel] = lambda do |inventory_collection|
        manager_uuids = inventory_collection.parent_inventory_collections.collect(&:manager_uuids).map(&:to_a).flatten
        ems = inventory_collection.parent
        ems.vm_and_template_taggings.where(
          'taggable_id'   => ems.vms_and_templates.where(:ems_ref => manager_uuids)
        )
      end

      attributes.merge!(extra_attributes)
    end

    def orchestration_stacks(extra_attributes = {})
      attributes = {
        :model_class                 => ::ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack,
        :inventory_object_attributes => [
          :type,
          :ext_management_system,
          :ems_ref,
          :name,
          :description,
          :status,
          :status_reason,
          :parent,
          :orchestration_template,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def orchestration_stacks_resources(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :ems_ref,
          :stack,
          :name,
          :logical_resource,
          :physical_resource,
          :resource_category,
          :resource_status,
          :resource_status_reason,
          :last_updated,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def orchestration_stacks_outputs(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :ems_ref,
          :stack,
          :key,
          :value,
          :description,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def orchestration_stacks_parameters(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => [
          :ems_ref,
          :stack,
          :name,
          :value,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def orchestration_templates(extra_attributes = {})
      attributes = {
        :model_class                 => ::OrchestrationTemplateCfn,
        :inventory_object_attributes => [
          :type,
          :ems_ref,
          :name,
          :description,
          :content,
          :orderable,
        ]
      }

      super(attributes.merge!(extra_attributes))
    end

    def disks(extra_attributes = {})
      attributes = {
        :inventory_object_attributes => %i(hardware device_name device_type controller_type location size backing),
      }

      super(attributes.merge!(extra_attributes))
    end
  end
end
