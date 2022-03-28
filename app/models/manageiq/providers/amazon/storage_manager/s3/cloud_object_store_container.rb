class ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreContainer < ::CloudObjectStoreContainer
  supports :create

  supports :delete do
    unless ext_management_system
      unsupported_reason_add(:delete, _("The Storage Container is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      })
    end
  end

  supports :cloud_object_store_container_clear do
    unless ext_management_system
      unsupported_reason_add(
        :cloud_object_store_container_clear,
        _("The Storage Container is not connected to an active %{table}") % {
          :table => ui_lookup(:table => "ext_management_systems")
        }
      )
    end

    unless cloud_object_store_objects.count.positive?
      unsupported_reason_add(:cloud_object_store_container_clear, _("The Storage Container is already empty"))
    end
  end

  def provider_object(connection = nil)
    connect(connection).bucket(ems_ref)
  end

  def connect(connection = nil)
    connection ||= ext_management_system.connect
    region = connection.client.get_bucket_location(:bucket => ems_ref).location_constraint
    region = "us-east-1" if region.empty? # SDK returns empty string for default region
    ext_management_system.connect(:region => region)
  end

  def raw_delete
    with_provider_object(&:delete!)
  end

  def raw_cloud_object_store_container_clear
    with_provider_object(&:clear!)
  end

  def self.raw_cloud_object_store_container_create(ext_management_system, options)
    # frontend stores name as :name, but amazon expects it as :bucket
    options[:bucket] = options.delete(:name) unless options[:name].nil?

    region = options[:create_bucket_configuration][:location_constraint]
    connection = ext_management_system.connect(:region => region)
    bucket = connection.create_bucket(options)
    {
      :key                   => bucket.name,
      :ems_ref               => bucket.name,
      :bytes                 => 0,
      :object_count          => 0,
      :ext_management_system => ext_management_system
    }
  rescue => e
    $aws_log.error "raw_cloud_object_store_container_create error, options=[#{options}], error: #{e}"
    raise MiqException::Error, e.to_s, e.backtrace
  end
end
