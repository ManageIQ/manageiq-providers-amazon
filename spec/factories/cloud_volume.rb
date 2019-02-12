FactoryBot.define do
  factory :cloud_volume_amazon, :parent => :cloud_volume,
                                :class  => "ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume"
  factory :cloud_volume_amazon_standard,
          :parent => :cloud_volume,
          :class  => "ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume" do
    size { 1.gigabyte }
    volume_type { 'standard' }
  end

  factory :cloud_volume_amazon_gp2,
          :parent => :cloud_volume,
          :class  => "ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume" do
    size { 1.gigabyte }
    volume_type { 'gp2' }
  end

  factory :cloud_volume_amazon_io1,
          :parent => :cloud_volume,
          :class  => "ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume" do
    size { 4.gigabytes }
    volume_type { 'io1' }
  end
end
