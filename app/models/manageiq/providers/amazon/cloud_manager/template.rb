class ManageIQ::Providers::Amazon::CloudManager::Template < ManageIQ::Providers::CloudManager::Template
  include ManageIQ::Providers::Amazon::CloudManager::VmOrTemplateShared

  supports :provisioning do
    if !ext_management_system
      _("not connected to ems")
    else
      ext_management_system.unsupported_reason(:provisioning)
    end
  end

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.image(ems_ref)
  end

  def proxies4job(_job = nil)
    {
      :proxies => [MiqServer.my_server],
      :message => 'Perform SmartState Analysis on this Image'
    }
  end

  def self.display_name(number = 1)
    n_('Image (Amazon)', 'Images (Amazon)', number)
  end
end
