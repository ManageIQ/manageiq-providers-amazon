FactoryGirl.define do
  factory :ems_amazon_ebs,
          :aliases => ["manageiq/providers/amazon/storage_manager/ebs"],
          :class   => "ManageIQ::Providers::Amazon::StorageManager::Ebs",
          :parent  => :ems_storage do
    provider_region "us-east-1"
  end
end
