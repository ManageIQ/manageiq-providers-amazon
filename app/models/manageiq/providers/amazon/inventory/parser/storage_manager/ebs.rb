class ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::Ebs < ::ManagerRefresh::RefreshParserInventoryObject
  include ManageIQ::Providers::Amazon::RefreshHelperMethods

  def ems
    inventory.ems.respond_to?(:ebs_storage_manager) ? inventory.ems.ebs_storage_manager : inventory.ems
  end

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
    process_inventory_collection(inventory.collector.cloud_volumes, :cloud_volumes) { |volume| parse_volume(volume) }
  end

  def get_snapshots
    process_inventory_collection(inventory.collector.cloud_volume_snapshots, :cloud_volume_snapshots) { |snap| parse_snapshot(snap) }
  end

  def parse_volume(volume)
    uid = volume['volume_id']

    volume_hash = {
      :type                  => self.class.volume_type,
      :ext_management_system => ems,
      :ems_ref               => uid,
      :name                  => get_from_tags(volume, :name) || uid,
      :status                => volume['state'],
      :creation_time         => volume['create_time'],
      :volume_type           => volume['volume_type'],
      :size                  => volume['size'].to_i.gigabytes,
      :base_snapshot         => inventory_collections[:cloud_volume_snapshots].lazy_find(volume['snapshot_id']),
      :availability_zone     => inventory_collections[:availability_zones].lazy_find(volume['availability_zone'])
    }

    link_volume_to_disk(volume_hash, volume['attachments'])

    volume_hash
  end

  def parse_snapshot(snap)
    uid = snap['snapshot_id']

    {
      :type                  => self.class.volume_snapshot_type,
      :ext_management_system => ems,
      :ems_ref               => uid,
      :name                  => get_from_tags(snap, :name) || uid,
      :status                => snap['state'],
      :creation_time         => snap['start_time'],
      :description           => snap['description'],
      :size                  => snap['volume_size'].to_i.gigabytes,
      :cloud_volume          => inventory_collections[:cloud_volumes].lazy_find(snap['volume_id'])
    }
  end

  # Overridden helper methods, we should put them in helper once we get rid of old refresh
  def get_from_tags(resource, item)
    (resource['tags'] || []).detect { |tag, _| tag['key'].downcase == item.to_s.downcase }.try(:[], 'value')
  end

  def link_volume_to_disk(volume_hash, attachments)
    uid = volume_hash[:ems_ref]

    (attachments || []).each do |a|
      if a['device'].blank?
        _log.warn "#{log_header}: Volume: #{uid}, is missing a mountpoint, skipping the volume processing"
        _log.warn "#{log_header}:   EMS: #{@ems.name}, Instance: #{a['instance_id']}"
        next
      end

      dev = File.basename(a['device'])

      disk_hash = {
        :hardware    => inventory_collections[:hardwares].lazy_find(a["instance_id"]),
        :device_name => dev,
        :location    => dev,
        :size        => volume_hash[:size],
        :backing     => inventory_collections[:cloud_volumes].lazy_find(uid),
      }
      inventory_collections[:disks] << inventory_collections[:disks].new_inventory_object(disk_hash)
    end
  end

  class << self
    def volume_type
      "ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume"
    end

    def volume_snapshot_type
      "ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot"
    end
  end
end
