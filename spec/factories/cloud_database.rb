FactoryBot.define do
  factory :cloud_database_amazon,
          :class => "ManageIQ::Providers::Amazon::CloudManager::CloudDatabase"
end
