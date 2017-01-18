class ManageIQ::Providers::Amazon::StorageManager::S3::RefreshParser
  include ManageIQ::Providers::Amazon::RefreshHelperMethods

  def initialize(ems, options = nil)
    @ems        = ems
    @aws_s3     = ems.connect(:service => :S3)
    @data       = {}
    @data_index = {}
    @options    = options || {}
  end

  def ems_inv_to_hashes
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

    $aws_log.info("#{log_header}...")
    object_store

    $aws_log.info("#{log_header}...Complete")

    @data
  end

  def object_store
    buckets = @aws_s3.client.list_buckets.buckets
    process_collection(buckets, :cloud_object_store_containers) { |c| parse_container(c) }
  end

  def parse_container(bucket)
    uid = bucket.name

    new_result = {
      :ems_ref => uid,
      :key     => bucket.name
    }
    return uid, new_result
  end

  def parse_object(obj, bucket)
    uid = obj.key

    new_result = {
      :ems_ref        => uid,
      :etag           => obj.etag,
      :last_modified  => obj.last_modified,
      :content_length => obj.size,
      :key            => obj.key,
      #:content_type   => obj.content_type,
      :container      => bucket
    }
    return uid, new_result
  end
end
