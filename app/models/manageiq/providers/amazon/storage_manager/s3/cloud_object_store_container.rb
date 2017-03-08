class ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreContainer < ::CloudObjectStoreContainer
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
    connection ||= ext_management_system.connect
    connection.bucket(ems_ref)
  end

  def raw_delete
    with_provider_object(&:delete!)
  end

  def raw_cloud_object_store_container_clear
    with_provider_object(&:clear!)
  end
end
