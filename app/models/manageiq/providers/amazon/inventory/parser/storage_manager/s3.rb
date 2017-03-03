class ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::S3 < ManageIQ::Providers::Amazon::Inventory::Parser
  def ems
    collector.manager.respond_to?(:s3_storage_manager) ? collector.manager.s3_storage_manager : collector.manager
  end

  def parse
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{collector.manager.name}] id: [#{collector.manager.id}]"

    $aws_log.info("#{log_header}...}")
    process_containers
    $aws_log.info("#{log_header}...Complete")
  end

  private

  def process_containers
    process_inventory_collection(
      collector.cloud_object_store_containers,
      :cloud_object_store_containers
    ) { |c| parse_container(c) }
    persister.collections[:cloud_object_store_containers].data_index.each do |bucket_id, object|
      lazy_object = persister.collections[:cloud_object_store_containers].lazy_find(bucket_id)
      object_stats = process_objects(bucket_id, lazy_object)
      object.data.merge!(object_stats)
    end
  end

  def parse_container(bucket)
    uid = bucket['name']
    {
      :type                  => self.class.container_type,
      :ext_management_system => ems,
      :ems_ref               => uid,
      :key                   => bucket['name']
    }
  end

  def process_objects(bucket_id, bucket_object)
    # S3 bucket accessible only for API client with same region
    region = collector.aws_s3.client.get_bucket_location(:bucket => bucket_id).location_constraint
    options = { :region => region, :bucket => bucket_id }

    # AWS SDK doesn't show information about overall size and object count.
    # We need to collect it manually.
    bytes = 0
    object_count = 0
    proceed = true
    while proceed
      objects, token = collector.cloud_object_store_objects(options)
      options[:token] = token

      process_inventory_collection(objects, :cloud_object_store_objects) do |o|
        new_result = parse_object(o, bucket_object)
        bytes += new_result[:content_length]
        object_count += 1
        new_result
      end

      proceed = token.present?
    end

    { :bytes => bytes, :object_count => object_count }
  end

  def parse_object(object, bucket)
    uid = object['key']
    {
      :ext_management_system        => ems,
      :ems_ref                      => "#{bucket.ems_ref}_#{uid}",
      :etag                         => object['etag'],
      :last_modified                => object['last_modified'],
      :content_length               => object['size'],
      :key                          => uid,
      :cloud_object_store_container => bucket
    }
  end

  class << self
    def container_type
      ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreContainer.name
    end
  end
end
