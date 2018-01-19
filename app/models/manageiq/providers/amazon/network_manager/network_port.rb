class ManageIQ::Providers::Amazon::NetworkManager::NetworkPort < ::NetworkPort
  def self.display_name(number = 1)
    n_('Network Port (Amazon)', 'Network Ports (Amazon)', number)
  end
end
