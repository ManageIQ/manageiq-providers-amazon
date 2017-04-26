class ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::Ebs < ManageIQ::Providers::Amazon::Inventory::Parser
  def ems
    collector.manager.respond_to?(:ebs_storage_manager) ? collector.manager.ebs_storage_manager : collector.manager
  end

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
      uid = volume['volume_id']

      persister_volume = persister.cloud_volumes.find_or_build(uid)
      persister_volume.assign_attributes(
        :ext_management_system => ems,
        :ems_ref               => uid,
        :name                  => get_from_tags(volume, :name) || uid,
        :status                => volume['state'],
        :creation_time         => volume['create_time'],
        :volume_type           => volume['volume_type'],
        :size                  => volume['size'].to_i.gigabytes,
        :base_snapshot         => persister.cloud_volume_snapshots.lazy_find(volume['snapshot_id']),
        :availability_zone     => persister.availability_zones.lazy_find(volume['availability_zone'])
      )

      link_volume_to_disk(persister_volume, volume['attachments'])
    end
  end

  def snapshots
    collector.cloud_volume_snapshots.each do |snap|
      uid = snap['snapshot_id']

      persister_snapshot = persister.cloud_volume_snapshots.find_or_build(uid)
      persister_snapshot.assign_attributes(
        :ext_management_system => ems,
        :ems_ref               => uid,
        :name                  => get_from_tags(snap, :name) || uid,
        :status                => snap['state'],
        :creation_time         => snap['start_time'],
        :description           => snap['description'],
        :size                  => snap['volume_size'].to_i.gigabytes,
        :cloud_volume          => persister.cloud_volumes.lazy_find(snap['volume_id'])
      )
    end
  end

  # Overridden helper methods, we should put them in helper once we get rid of old refresh
  def get_from_tags(resource, item)
    (resource['tags'] || []).detect { |tag, _| tag['key'].downcase == item.to_s.downcase }.try(:[], 'value')
  end

  def link_volume_to_disk(persister_volume, attachments)
    (attachments || []).each do |a|
      if a['device'].blank?
        log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{ems.name}] id: [#{ems.id}]"
        $aws_log.warn "#{log_header}: Volume: #{persister_volume.ems_ref}, is missing a mountpoint, skipping the volume processing"
        $aws_log.warn "#{log_header}: EMS: #{ems.name}, Instance: #{a['instance_id']}"
        next
      end

      dev = File.basename(a['device'])

      disk = persister.disks.find_or_build_by(:hardware    => persister.hardwares.lazy_find(a["instance_id"]),
                                              :device_name => dev)
      disk.location = dev
      disk.size     = persister_volume.size
      disk.backing  = persister_volume
    end
  end
end
