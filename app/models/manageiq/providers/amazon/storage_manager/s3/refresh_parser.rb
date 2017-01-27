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
    process_collection(
      @aws_s3.client.list_buckets.buckets,
      :cloud_object_store_containers
    ) { |c| parse_container(c) }

    process_containers_content
  end

  def process_containers_content
    containers = @data[:cloud_object_store_containers]
    if containers.empty?
      process_collection([], :cloud_object_store_objects)
      return
    end

    containers.each do |bucket|
      bucket_id = bucket[:ems_ref]

      # S3 bucket accessible only for API client with same region
      region = @aws_s3.client.get_bucket_location(:bucket => bucket_id).location_constraint
      api_client = regional_client(region)

      # AWS SDK doesn't show information about overall size and object count.
      # We need to collect it manually.
      bytes = 0
      object_count = 0
      # API returns up to 1000 objects per request
      token = nil
      proceed = true
      while proceed
        response = api_client.list_objects_v2(
          :bucket             => bucket_id,
          :continuation_token => token
        )
        process_collection(response.contents, :cloud_object_store_objects) do |o|
          uid, new_result = parse_object(o, bucket_id)
          bytes += new_result[:content_length]
          object_count += 1
          [uid, new_result]
        end
        token = response.next_continuation_token

        proceed = token.present?
      end
      bucket[:bytes] = bytes
      bucket[:object_count] = object_count
    end
  end

  def regional_client(region)
    if !region || region == @ems.provider_region
      @aws_s3
    else
      @regional_resources ||= {}
      @regional_resources[region] ||= @ems.connect(:service => :S3, :region => region)
    end.client
  end

  def parse_container(bucket)
    uid = bucket.name

    new_result = {
      :ems_ref => uid,
      :key     => bucket.name
    }
    return uid, new_result
  end

  def parse_object(object, bucket_id)
    uid = object.key

    new_result = {
      :ems_ref                         => "#{bucket_id}_#{uid}",
      :etag                            => object.etag,
      :last_modified                   => object.last_modified,
      :content_length                  => object.size,
      :key                             => object.key,
      :cloud_object_store_container_id => @data_index.fetch_path(:cloud_object_store_containers, bucket_id)
    }
    return uid, new_result
  end
end
