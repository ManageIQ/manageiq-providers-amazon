class ManageIQ::Providers::Amazon::StorageManager::Ebs::RefreshParser
  include ManageIQ::Providers::Amazon::RefreshHelperMethods

  def initialize(ems, options = nil)
    @ems        = ems
    @aws_ec2    = ems.connect
    @data       = {}
    @data_index = {}
    @options    = options || {}
  end

  def ems_inv_to_hashes
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

    $aws_log.info("#{log_header}...")
    get_volumes
    get_snapshots
    $aws_log.info("#{log_header}...Complete")

    link_storage_associations

    @data
  end

  def get_volumes
    volumes = @aws_ec2.client.describe_volumes[:volumes]
    process_collection(volumes, :cloud_volumes) { |volume| parse_volume(volume) }
  end

  def get_snapshots
    snapshots = @aws_ec2.client.describe_snapshots(:owner_ids => [:self])[:snapshots]
    process_collection(snapshots, :cloud_volume_snapshots) { |snap| parse_snapshot(snap) }
  end

  def parse_volume(volume)
    uid = volume.volume_id

    new_result = {
      :type          => self.class.volume_type,
      :ems_ref       => uid,
      :name          => uid,
      :status        => volume.state,
      :creation_time => volume.create_time,
      :volume_type   => volume.volume_type,
      :size          => volume.size.to_i.gigabytes,
      :snapshot_uid  => volume.snapshot_id
    }

    return uid, new_result
  end

  def parse_snapshot(snap)
    uid = snap.snapshot_id

    new_result = {
      :ems_ref       => uid,
      :type          => self.class.volume_snapshot_type,
      :name          => snap.snapshot_id,
      :status        => snap.state,
      :creation_time => snap.start_time,
      :description   => snap.description,
      :size          => snap.volume_size.to_i.gigabytes,
      :volume        => @data_index.fetch_path(:cloud_volumes, snap.volume_id)
    }

    return uid, new_result
  end

  def link_storage_associations
    @data[:cloud_volumes].each do |cv|
      base_snapshot_uid = cv.delete(:snapshot_uid)
      base_snapshot = @data_index.fetch_path(:cloud_volume_snapshots, base_snapshot_uid)
      cv[:base_snapshot] = base_snapshot unless base_snapshot.nil?
    end if @data[:cloud_volumes]
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
