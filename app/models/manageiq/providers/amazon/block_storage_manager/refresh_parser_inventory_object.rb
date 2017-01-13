class ManageIQ::Providers::Amazon::BlockStorageManager::RefreshParserInventoryObject < ::ManagerRefresh::RefreshParserInventoryObject
  include ManageIQ::Providers::Amazon::RefreshHelperMethods

  def populate_inventory_collections
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{inventory.ems.name}] id: [#{inventory.ems.id}]"

    $aws_log.info("#{log_header}...}")
    get_volumes
    get_snapshots
    $aws_log.info("#{log_header}...Complete")

    inventory_collections
  end

  private

  def get_volumes
    process_inventory_collection(inventory.cloud_volumes, :cloud_volumes) { |volume| parse_volume(volume) }
  end

  def get_snapshots
    process_inventory_collection(inventory.cloud_volume_snapshots, :cloud_volume_snapshots) { |snap| parse_snapshot(snap) }
  end

  def parse_volume(volume)
    uid = volume['volume_id']

    {
      :type          => self.class.volume_type,
      :ems_ref       => uid,
      :name          => uid,
      :status        => volume['state'],
      :creation_time => volume['create_time'],
      :volume_type   => volume['volume_type'],
      :size          => volume['size'].to_i.gigabytes
    }
  end

  def parse_snapshot(snap)
    uid = snap['snapshot_id']

    {
      :ems_ref       => uid,
      :type          => self.class.volume_snapshot_type,
      :name          => snap['snapshot_id'],
      :status        => snap['state'],
      :creation_time => snap['start_time'],
      :description   => snap['description'],
      :size          => snap['volume_size'],
      :cloud_volume  => inventory_collections[:cloud_volumes].lazy_find(snap['volume_id'])
    }
  end

  class << self
    def volume_type
      "ManageIQ::Providers::Amazon::BlockStorageManager::CloudVolume"
    end

    def volume_snapshot_type
      "ManageIQ::Providers::Amazon::BlockStorageManager::CloudVolumeSnapshot"
    end
  end
end
