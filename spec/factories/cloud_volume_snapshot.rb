FactoryGirl.define do
  factory :cloud_volume_snapshot_amazon, :parent => :cloud_volume_snapshot,
                                         :class  => "ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot"
end
