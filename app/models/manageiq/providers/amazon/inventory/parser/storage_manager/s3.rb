class ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::S3 < ManageIQ::Providers::Amazon::Inventory::Parser
  def parse
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{collector.manager.name}] id: [#{collector.manager.id}]"

    $aws_log.info("#{log_header}...}")
    containers
    $aws_log.info("#{log_header}...Complete")
  end

  private

  def containers
    collector.cloud_object_store_containers.each do |container|
      container_id = container['name']

      persister_container = persister.cloud_object_store_containers.find_or_build(container_id).assign_attributes(
        :ems_ref => container_id,
        :key     => container['name']
      )

      # Assign number of objects and size in KB of the all container objects
      persister_container.assign_attributes(container_objects(container_id, persister_container))
    end
  end

  def container_objects(container_id, persister_container)
    # S3 bucket accessible only for API client with same region
    region       = collector.aws_s3.client.get_bucket_location(:bucket => container_id).location_constraint
    region       = "us-east-1" if region.empty? # SDK returns empty string for default region
    options      = {:region => region, :bucket => container_id}

    # AWS SDK doesn't show information about overall size and object count.
    # We need to collect it manually.
    bytes        = 0
    object_count = 0
    proceed      = true
    while proceed
      objects, token  = collector.cloud_object_store_objects(options)
      options[:token] = token

      objects.each do |container_object|
        bytes        += container_object(container_object, container_id, persister_container).content_length
        object_count += 1
      end

      proceed = token.present?
    end

    {:bytes => bytes, :object_count => object_count}
  end

  def container_object(container_object, container_id, persister_container)
    uid     = container_object['key']
    ems_ref = "#{container_id}_#{uid}"

    persister.cloud_object_store_objects.find_or_build(ems_ref).assign_attributes(
      :etag                         => container_object['etag'],
      :last_modified                => container_object['last_modified'],
      :content_length               => container_object['size'],
      :key                          => uid,
      :cloud_object_store_container => persister_container
    )
  end
end
