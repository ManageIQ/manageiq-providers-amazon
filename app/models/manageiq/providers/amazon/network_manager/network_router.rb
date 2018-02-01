class ManageIQ::Providers::Amazon::NetworkManager::NetworkRouter < ::NetworkRouter
  def self.display_name(number = 1)
    n_('Network Router (Amazon)', 'Network Routers (Amazon)', number)
  end
end
