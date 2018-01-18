class ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet < ::CloudSubnet
  def self.display_name(number = 1)
    n_('Cloud Subnet (Amazon)', 'Cloud Subnets (Amazon)', number)
  end
end
