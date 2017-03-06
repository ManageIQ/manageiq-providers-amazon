class ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreObject < ::CloudObjectStoreObject
  supports :delete do
    unless ext_management_system
      unsupported_reason_add(:delete, _("The Storage Object is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      })
    end

    unless cloud_object_store_container
      unsupported_reason_add(:delete, _("The Storage Object is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "cloud_object_store_containers")
      })
    end
  end

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.bucket(cloud_object_store_container.ems_ref).object(key)
  end

  def raw_delete
    with_provider_object(&:delete)
  end
end
