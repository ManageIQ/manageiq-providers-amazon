module ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::StorageCollections
  extend ActiveSupport::Concern

  def initialize_storage_inventory_collections
    # should be defined by concrete persisters
  end

  # ------ IC provider specific definitions -------------------------

  def add_cloud_volumes(extra_properties = {})
    add_collection(storage, :cloud_volumes, extra_properties) do |builder|
      builder.add_properties(:model_class => ::ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume)
      builder.add_properties(:parent => manager.ebs_storage_manager) if targeted?

      builder.add_default_values(
        :ems_id => block_storage_manager_id
      )
    end
  end

  def add_cloud_volume_snapshots(extra_properties = {})
    add_collection(storage, :cloud_volume_snapshots, extra_properties) do |builder|
      builder.add_properties(:model_class => ::ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot)
      builder.add_properties(:parent => manager.ebs_storage_manager) if targeted?

      builder.add_default_values(
        :ems_id => block_storage_manager_id
      )
    end
  end

  def add_cloud_object_store_containers(extra_properties = {})
    add_collection(storage, :cloud_object_store_containers, extra_properties) do |builder|
      builder.add_properties(:model_class => ::ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreContainer)
      builder.add_properties(:parent => manager.s3_storage_manager) if targeted?

      builder.add_default_values(
        :ems_id => object_storage_manager_id
      )
    end
  end

  def add_cloud_object_store_objects(extra_properties = {})
    add_collection(storage, :cloud_object_store_objects, extra_properties) do |builder|
      builder.add_properties(:model_class => ::ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreObject)
      builder.add_properties(:parent => manager.s3_storage_manager) if targeted?

      builder.add_default_values(
        :ems_id => object_storage_manager_id
      )
    end
  end

  protected

  def block_storage_manager_id
    manager.try(:ebs_storage_manager).try(:id) || manager.id
  end

  def object_storage_manager_id
    manager.try(:s3_storage_manager).try(:id) || manager.id
  end
end
