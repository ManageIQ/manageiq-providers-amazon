class ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume < ::CloudVolume
  supports :create
  supports :snapshot_create

  CLOUD_VOLUME_TYPES = {
    :gp2      => N_('General Purpose SSD (GP2)'),
    :io1      => N_('Provisioned IOPS SSD (IO1)'),
    :st1      => N_('Throughput Optimized HDD (ST1)'),
    :sc1      => N_('Cold HDD (SC1)'),
    :standard => N_('Magnetic'),
  }.freeze

  def available_vms
    availability_zone.vms
  end

  def self.validate_create_volume(ext_management_system)
    validate_volume(ext_management_system)
  end

  def self.raw_create_volume(ext_management_system, options)
    options.symbolize_keys!
    options.delete(:ems_id)
    volume_name = options.delete(:name)

    availability_zone = ext_management_system.availability_zones.find_by(:id => options.delete(:availability_zone_id))
    options[:availability_zone] = availability_zone&.ems_ref

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

  def self.params_for_create(ems)
    {
      :fields => [
        {
          :component  => 'text-field',
          :name       => 'size',
          :id         => 'size',
          :label      => _('Size (in bytes)'),
          :type       => 'number',
          :step       => 1.gigabytes,
          :isRequired => true,
          :validate   => [{:type => 'required'}],
          :condition  => {
            :or => [
              {
                :not => {
                  :when => 'volume_type',
                  :is   => 'standard',
                },
              },
              {
                :when => 'edit',
                :is   => false,
              },
            ],
          },
        },
        {
          :component    => 'select',
          :name         => 'availability_zone_id',
          :id           => 'availability_zone_id',
          :label        => _('Availability Zone'),
          :includeEmpty => true,
          :options      => ems.availability_zones.map do |az|
            {
              :label => az.name,
              :value => az.id,
            }
          end,
          :isRequired   => true,
          :validate     => [{:type => 'required'}],
          :condition    => {
            :when => 'edit',
            :is   => false,
          },
        },
        {
          :component    => 'select',
          :name         => 'volume_type',
          :id           => 'volume_type',
          :label        => _('Cloud Volume Type'),
          :includeEmpty => true,
          :options      => CLOUD_VOLUME_TYPES.map do |value, label|
            option = {
              :label => _(label),
              :value => value,
            }

            # The standard (magnetic) volume_type is a special case. I can only be set upon creation
            # or when editing an entity that has its volume_type set to standard. Conditional options
            # are not supported by DDF, but resolveProps allows us to overwrite these options before
            # rendering.
            if value == :standard
              option[:condition] = {
                :or => [
                  {
                    :when => 'edit',
                    :is   => false,
                  },
                  {
                    :when => 'volume_type',
                    :is   => 'standard',
                  }
                ]
              }
            end

            option
          end,
          :isRequired   => true,
          :validate     => [{:type => 'required'}],
          :initialValue => 'gp2',
        },
        {
          :component => 'text-field',
          :name      => 'iops',
          :id        => 'iops',
          :label     => _('IOPS'),
          :type      => 'number',
          :condition => {
            :when => 'volume_type',
            :is   => 'io1',
          }
        },
        {
          :component    => 'select',
          :name         => 'cloud_volume_snapshot_id',
          :id           => 'cloud_volume_snapshot_id',
          :label        => _('Base Snapshot'),
          :includeEmpty => true,
          :condition    => {
            :when => 'edit',
            :is   => false,
          },
          :options      => ems.cloud_volume_snapshots.map do |cvs|
            {
              :value => cvs.id,
              :label => cvs.name,
            }
          end
        },
        {
          :component  => 'switch',
          :name       => 'encrypted',
          :id         => 'encrypted',
          :label      => _('Encrypted'),
          :onText     => _('Yes'),
          :offText    => _('No'),
          :isRequired => true,
          :condition  => {
            :when => 'edit',
            :is   => false,
          },
        }
      ]
    }
  end

  private

  def modify_volume_options(options = {})
    modify_opts = {}

    if volume_type != 'standard'
      modify_opts[:volume_type] = options[:volume_type] if options[:volume_type] && options[:volume_type] != volume_type
      modify_opts[:size]        = Integer(options[:size]) if options[:size] && Integer(options[:size]).gigabytes != size
      modify_opts[:iops]        = options[:iops] if (options[:volume_type] == "io1" || volume_type == 'io1') && options[:iops]
    end

    modify_opts
  end
end
