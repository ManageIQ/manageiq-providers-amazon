class ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot < ::CloudVolumeSnapshot
  supports :create
  supports :update
  supports :delete

  def self.create_snapshot_queue(userid, cloud_volume, options = {})
    ext_management_system = cloud_volume.try(:ext_management_system)
    task_opts = {
      :action => "creating volume snapshot in #{ext_management_system.inspect} for #{cloud_volume.inspect} with #{options.inspect}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => cloud_volume.class.name,
      :instance_id => cloud_volume.id,
      :method_name => 'create_volume_snapshot',
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone(ext_management_system),
      :args        => [options]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def self.create_snapshot(cloud_volume, options = {})
    raise ArgumentError, _("cloud_volume cannot be nil") if cloud_volume.nil?
    ext_management_system = cloud_volume.try(:ext_management_system)
    raise ArgumentError, _("ext_management_system cannot be nil") if ext_management_system.nil?

    snapshot_name = options.delete(:name) if options.key?(:name)
    snapshot = nil

    ext_management_system.with_provider_connection do |service|
      # Create the volume using provided options.
      snapshot = service.client.create_snapshot(
        :volume_id   => cloud_volume.ems_ref,
        :description => options[:description]
      )

      if snapshot_name
        service.client.create_tags(
          :resources => [snapshot.snapshot_id],
          :tags      => [{ :key => "Name", :value => snapshot_name }]
        )
      end
    end

    create(
      :name                  => snapshot_name,
      :description           => snapshot.description,
      :ems_ref               => snapshot.snapshot_id,
      :status                => snapshot.state,
      :cloud_volume          => cloud_volume,
      :ext_management_system => ext_management_system,
    )
  rescue => e
    _log.error "snapshot=[#{options[:name]}], error: #{e}"
    raise MiqException::MiqVolumeSnapshotCreateError, e.to_s, e.backtrace
  end

  def raw_delete_snapshot
    with_provider_object(&:delete)
    update!(:status => 'deleting')
    EmsRefresh.queue_refresh(
      ManagerRefresh::Target.new(
        :association => :cloud_volume_snapshots,
        :manager_ref => { :ems_ref => ems_ref },
        :manager_id  => ems_id,
      )
    )
  rescue => e
    _log.error "volume=[#{name}], error: #{e}"
    raise MiqException::MiqVolumeSnapshotDeleteError, e.to_s, e.backtrace
  end

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.snapshot(ems_ref)
  end
end
