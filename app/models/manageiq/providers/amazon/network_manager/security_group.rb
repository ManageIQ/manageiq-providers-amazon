class ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup < ::SecurityGroup
  def self.display_name(number = 1)
    n_('Security Group (Amazon)', 'Security Groups (Amazon)', number)
  end
end
