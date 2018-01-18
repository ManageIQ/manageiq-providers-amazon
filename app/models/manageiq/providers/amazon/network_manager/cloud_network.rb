class ManageIQ::Providers::Amazon::NetworkManager::CloudNetwork < ::CloudNetwork
  def self.display_name(number = 1)
    n_('Cloud Network (Amazon)', 'Cloud Networks (Amazon)', number)
  end
end
