class ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreContainer < ::CloudObjectStoreContainer
  supports :delete do
    unless ext_management_system
      unsupported_reason_add(:delete, _("The Storage Container is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      })
    end
  end

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.bucket(ems_ref)
  end

  def raw_delete
    with_provider_object(&:delete!)
  end
end
