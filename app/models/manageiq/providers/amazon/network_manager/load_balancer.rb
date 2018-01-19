class ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer < ::LoadBalancer
  def self.display_name(number = 1)
    n_('Load Balancer (Amazon)', 'Load Balancers (Amazon)', number)
  end
end
