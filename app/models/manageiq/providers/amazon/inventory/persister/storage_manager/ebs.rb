class ManageIQ::Providers::Amazon::Inventory::Persister::StorageManager::Ebs < ManageIQ::Providers::Amazon::Inventory::Persister
  include ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::CloudCollections
  include ManageIQ::Providers::Amazon::Inventory::Persister::Definitions::StorageCollections

  def initialize_inventory_collections
    initialize_storage_inventory_collections

    initialize_cloud_inventory_collections
  end

  def initialize_storage_inventory_collections
    add_cloud_volumes

    add_cloud_volume_snapshots
  end

  def initialize_cloud_inventory_collections
    %i(availability_zones
       hardwares
       vms
       disks).each do |name|

      add_collection(cloud, name) do |builder|
        builder.add_properties(:parent => manager.parent_manager)

        builder.add_properties(:update_only => true) if name == :disks
        builder.add_properties(:strategy => :local_db_cache_all) unless name == :disks
      end
    end
  end
end
