class ManageIQ::Providers::Amazon::NetworkManager::FloatingIp < ::FloatingIp
  def self.display_name(number = 1)
    n_('Floating IP (Amazon)', 'Floating IPs (Amazon)', number)
  end
end
