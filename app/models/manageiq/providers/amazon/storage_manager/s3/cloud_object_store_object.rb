class ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreObject < ::CloudObjectStoreObject
  supports :delete do
    if !ext_management_system
      _("The Storage Object is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "ext_management_systems")
      }
    elsif !cloud_object_store_container
      _("The Storage Object is not connected to an active %{table}") % {
        :table => ui_lookup(:table => "cloud_object_store_containers")
      }
    end
  end

  def provider_object(connection = nil)
    cloud_object_store_container.provider_object(connection).object(key)
  end

  def raw_delete
    if key.end_with? "/" # delete object with subobjects (aka. folder)
      cloud_object_store_container.provider_object.objects(:prefix => key).batch_delete!
    else # delete single object
      with_provider_object(&:delete)
    end
  end
end
