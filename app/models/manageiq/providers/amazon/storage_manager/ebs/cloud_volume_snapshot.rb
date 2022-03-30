class ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot < ::CloudVolumeSnapshot
  supports :create
  supports :update
  supports :delete

  def self.raw_create_snapshot(cloud_volume, options = {})
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
      InventoryRefresh::Target.new(
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
