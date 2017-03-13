class ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::Ebs < ManageIQ::Providers::Amazon::Inventory::Parser
  def ems
    collector.manager.respond_to?(:ebs_storage_manager) ? collector.manager.ebs_storage_manager : collector.manager
  end

  def parse
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{collector.manager.name}] id: [#{collector.manager.id}]"

    $aws_log.info("#{log_header}...}")
    get_volumes
    get_snapshots
    $aws_log.info("#{log_header}...Complete")
  end

  private

  def get_volumes
    process_inventory_collection(collector.cloud_volumes, :cloud_volumes) { |volume| parse_volume(volume) }
  end

  def get_snapshots
    process_inventory_collection(collector.cloud_volume_snapshots, :cloud_volume_snapshots) { |snap| parse_snapshot(snap) }
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
      :base_snapshot         => persister.cloud_volume_snapshots.lazy_find(volume['snapshot_id']),
      :availability_zone     => persister.availability_zones.lazy_find(volume['availability_zone'])
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
      :cloud_volume          => persister.cloud_volumes.lazy_find(snap['volume_id'])
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

      disk = persister.disks.find_or_build_by(:hardware    => persister.hardwares.lazy_find(a["instance_id"]),
                                              :device_name => dev)
      disk.location = dev
      disk.size     = volume_hash[:size]
      disk.backing  = persister.cloud_volumes.lazy_find(uid)
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
