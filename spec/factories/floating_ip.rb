FactoryBot.define do
  factory :floating_ip_amazon, :parent => :floating_ip,
                               :class  => "ManageIQ::Providers::Amazon::NetworkManager::FloatingIp"
end
