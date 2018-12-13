FactoryBot.define do
  factory :aws_object, :class => ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreObject.name do |object|
    object.sequence(:key) { |n| "object-key-#{n}" }
  end

  factory :aws_bucket_with_objects,
          :class => ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreContainer.name do |bucket|
    bucket.sequence(:name) { |n| "stubbed-name-#{n}" }
    bucket.sequence(:ems_ref) { |n| "stubbed-ems-ref-#{n}" }

    after(:create) do |bucket|
      bucket.cloud_object_store_objects = FactoryBot.create_list(
        :aws_object, 5, :ext_management_system => bucket.ext_management_system
      )
    end
  end
end
