class ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume < ::CloudVolume
  supports :create

  def self.validate_create_volume(ext_management_system)
    validate_volume(ext_management_system)
  end

  def self.raw_create_volume(ext_management_system, options)
    volume_name = options.delete(:name)
    volume = nil

    ext_management_system.with_provider_connection do |service|
      # Create the volume using provided options.
      volume = service.client.create_volume(options)
      # Also name the volume using tags.
      service.client.create_tags(
        :resources => [volume.volume_id],
        :tags      => [{ :key => "Name", :value => volume_name }]
      )
    end
    {:ems_ref => volume.volume_id, :status => volume.state, :name => volume_name}
  rescue => e
    _log.error "volume=[#{volume_name}], error: #{e}"
    raise MiqException::MiqVolumeCreateError, e.to_s, e.backtrace
  end

  def validate_update_volume
    validate_volume
  end

  def raw_update_volume(options)
    # Only name update is currently supported
    if options.key?(:name)
      with_provider_object do |volume|
        volume.create_tags(:tags => [{:key => "Name", :value => options[:name]}])
      end
    end
  rescue => e
    _log.error "volume=[#{name}], error: #{e}"
    raise MiqException::MiqVolumeUpdateError, e.to_s, e.backtrace
  end

  def validate_delete_volume
    msg = validate_volume
    return {:available => msg[:available], :message => msg[:message]} unless msg[:available]
    if with_provider_object(&:state) == "in-use"
      return validation_failed("Create Volume", "Can't delete volume that is in use.")
    end
    {:available => true, :message => nil}
  end

  def raw_delete_volume
    with_provider_object(&:delete)
  rescue => e
    _log.error "volume=[#{name}], error: #{e}"
    raise MiqException::MiqVolumeDeleteError, e.to_s, e.backtrace
  end

  def validate_attach_volume
    validate_volume_available
  end

  def raw_attach_volume(server_ems_ref, device = nil)
    with_provider_object do |vol|
      vol.attach_to_instance(:instance_id => server_ems_ref, :device => device)
    end
  end

  def validate_detach_volume
    validate_volume_in_use
  end

  def raw_detach_volume(server_ems_ref)
    with_provider_object do |vol|
      vol.detach_from_instance(:instance_id => server_ems_ref)
    end
  end

  def create_volume_snapshot(options)
    ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot.create_snapshot(self, options)
  end

  def create_volume_snapshot_queue(userid, options)
    ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot.create_snapshot_queue(userid, self, options)
  end

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.volume(ems_ref)
  end
end
