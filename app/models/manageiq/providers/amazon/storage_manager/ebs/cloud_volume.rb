class ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume < ::CloudVolume
  supports :create
  supports :snapshot_create

  def available_vms
    availability_zone.vms
  end

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
    with_provider_object do |volume|
      # Update the name in case it was provided in the options.
      volume.create_tags(:tags => [{:key => "Name", :value => options[:name]}]) if options.key?(:name)

      # Mofiy volume configuration based on the given options.
      modify_opts = modify_volume_options(options)
      volume.client.modify_volume(modify_opts.merge(:volume_id => ems_ref)) unless modify_opts.empty?
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

  private

  def modify_volume_options(options = {})
    modify_opts = {}
    if volume_type != 'standard'
      modify_opts[:volume_type] = options[:volume_type] if options[:volume_type] && options[:volume_type] != 'standard'
      modify_opts[:size]        = Integer(options[:size]) if options[:size] && Integer(options[:size]).gigabytes != size
      modify_opts[:iops]        = options[:iops] if (options[:volume_type] == "io1" || volume_type == 'io1') && options[:iops]
    end

    modify_opts
  end
end
