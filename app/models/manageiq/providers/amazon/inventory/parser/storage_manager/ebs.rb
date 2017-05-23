class ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::Ebs < ManageIQ::Providers::Amazon::Inventory::Parser
  def parse
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{collector.manager.name}] id: [#{collector.manager.id}]"

    $aws_log.info("#{log_header}...}")
    volumes
    snapshots
    $aws_log.info("#{log_header}...Complete")
  end

  private

  def volumes
    collector.cloud_volumes.each do |volume|
      persister_volume = persister.cloud_volumes.find_or_build(volume['volume_id']).assign_attributes(
        :name              => get_from_tags(volume, :name) || volume['volume_id'],
        :status            => volume['state'],
        :creation_time     => volume['create_time'],
        :volume_type       => volume['volume_type'],
        :size              => volume['size'].to_i.gigabytes,
        :base_snapshot     => persister.cloud_volume_snapshots.lazy_find(volume['snapshot_id']),
        :availability_zone => persister.availability_zones.lazy_find(volume['availability_zone'])
      )

      volume_attachments(persister_volume, volume['attachments'])
    end
  end

  def snapshots
    collector.cloud_volume_snapshots.each do |snap|
      persister.cloud_volume_snapshots.find_or_build(snap['snapshot_id']).assign_attributes(
        :name          => get_from_tags(snap, :name) || snap['snapshot_id'],
        :status        => snap['state'],
        :creation_time => snap['start_time'],
        :description   => snap['description'],
        :size          => snap['volume_size'].to_i.gigabytes,
        :cloud_volume  => persister.cloud_volumes.lazy_find(snap['volume_id'])
      )
    end
  end

  def volume_attachments(persister_volume, attachments)
    (attachments || []).each do |a|
      if a['device'].blank?
        log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{collector.manager.name}] id: [#{collector.manager.id}]"
        $aws_log.warn "#{log_header}: Volume: #{persister_volume.ems_ref}, is missing a mountpoint, skipping the volume processing"
        $aws_log.warn "#{log_header}: EMS: #{collector.manager.name}, Instance: #{a['instance_id']}"
        next
      end

      dev = File.basename(a['device'])

      persister.disks.find_or_build_by(
        :hardware    => persister.hardwares.lazy_find(a["instance_id"]),
        :device_name => dev
      ).assign_attributes(
        :location => dev,
        :size     => persister_volume.size,
        :backing  => persister_volume,
      )
    end
  end
end
