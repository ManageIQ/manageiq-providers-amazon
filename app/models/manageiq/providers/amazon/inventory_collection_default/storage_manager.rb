class ManageIQ::Providers::Amazon::InventoryCollectionDefault::StorageManager < ManagerRefresh::InventoryCollectionDefault::StorageManager
  class << self
    def cloud_volumes(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume,
      }

      super(attributes.merge!(extra_attributes))
    end

    def cloud_volume_snapshots(extra_attributes = {})
      attributes = {
        :model_class => ::ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot,
      }

      super(attributes.merge!(extra_attributes))
    end
  end
end
