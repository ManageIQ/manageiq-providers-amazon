FactoryGirl.define do
  factory :cloud_volume_amazon, :parent => :cloud_volume,
                                :class  => "ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume"
end
