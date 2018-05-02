module ManageIQ::Providers::Amazon::Inventory::Persister::Shared::StorageCollections
  extend ActiveSupport::Concern

  # Builder class for Storage
  def storage
    ::ManagerRefresh::InventoryCollection::Builder::StorageManager
  end

  def add_cloud_volumes(extra_properties = {})
    add_collection(storage, :cloud_volumes, extra_properties) do |builder|
      builder.add_properties(
        :model_class => ::ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume
      )

      builder.add_builder_params(
        :ems_id => ->(persister) { persister.manager.try(:ebs_storage_manager).try(:id) || persister.manager.id }
      )
    end
  end

  def add_cloud_volume_snapshots(extra_properties = {})
    add_collection(storage, :cloud_volume_snapshots, extra_properties) do |builder|
      builder.add_properties(
        :model_class => ::ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot
      )

      builder.add_builder_params(
        :ems_id => ->(persister) { persister.manager.try(:ebs_storage_manager).try(:id) || persister.manager.id }
      )
    end
  end

  def add_cloud_object_store_containers(extra_properties = {})
    add_collection(storage, :cloud_object_store_containers, extra_properties) do |builder|
      builder.add_properties(
        :model_class => ::ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreContainer
      )

      builder.add_builder_params(
        :ems_id => ->(persister) { persister.manager.try(:s3_storage_manager).try(:id) || persister.manager.id }
      )
    end
  end

  def add_cloud_object_store_objects(extra_properties = {})
    add_collection(storage, :cloud_object_store_objects, extra_properties) do |builder|
      builder.add_properties(
        :model_class => ::ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreObject
      )

      builder.add_builder_params(
        :ems_id => ->(persister) { persister.manager.try(:s3_storage_manager).try(:id) || persister.manager.id }
      )
    end
  end
end
