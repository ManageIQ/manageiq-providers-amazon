module ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::StorageCollections
  extend ActiveSupport::Concern

  def initialize_storage_inventory_collections
    # should be defined by concrete persisters
  end

  # ------ IC provider specific definitions -------------------------

  def add_cloud_volumes(extra_properties = {})
    add_ebs_storage_collection(:cloud_volumes, extra_properties) do |builder|
      builder.add_properties(:model_class => ::ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume)
    end
  end

  def add_cloud_volume_snapshots(extra_properties = {})
    add_ebs_storage_collection(:cloud_volume_snapshots, extra_properties) do |builder|
      builder.add_properties(:model_class => ::ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot)
    end
  end

  def add_cloud_object_store_containers(extra_properties = {})
    add_s3_storage_collection(:cloud_object_store_containers, extra_properties) do |builder|
      builder.add_properties(:model_class => ::ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreContainer)
    end
  end

  def add_cloud_object_store_objects(extra_properties = {})
    add_s3_storage_collection(:cloud_object_store_objects, extra_properties) do |builder|
      builder.add_properties(:model_class => ::ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreObject)
    end
  end

  protected

  def add_s3_storage_collection(collection_name, extra_properties = {}, settings = {}, &block)
    settings[:parent] ||= s3_storage_manager
    add_collection(storage, collection_name, extra_properties, settings, &block)
  end

  def add_ebs_storage_collection(collection_name, extra_properties = {}, settings = {}, &block)
    settings[:parent] ||= ebs_storage_manager
    add_collection(storage, collection_name, extra_properties, settings, &block)
  end

  def s3_storage_manager
    manager.try(:s3_storage_manager) || manager
  end

  def ebs_storage_manager
    manager.try(:ebs_storage_manager) || manager
  end
end
