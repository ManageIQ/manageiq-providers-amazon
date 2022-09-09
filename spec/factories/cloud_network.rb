FactoryBot.define do
  factory :cloud_network_amazon,
          :class  => "ManageIQ::Providers::Amazon::NetworkManager::CloudNetwork",
          :parent => :cloud_network
end
