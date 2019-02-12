FactoryBot.define do
  factory :ems_amazon_ebs,
          :aliases => ["manageiq/providers/amazon/storage_manager/ebs"],
          :class   => "ManageIQ::Providers::Amazon::StorageManager::Ebs",
          :parent  => :ems_storage do
    provider_region { "us-east-1" }
  end

  factory :ems_amazon_with_vcr_authentication, :parent => :ems_amazon do
    zone do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      zone
    end
    after(:create) do |ems|
      client_id  = Rails.application.secrets.amazon.try(:[], 'client_id') || 'AMAZON_CLIENT_ID'
      client_key = Rails.application.secrets.amazon.try(:[], 'client_secret') || 'AMAZON_CLIENT_SECRET'

      cred = {
        :userid   => client_id,
        :password => client_key
      }

      ems.authentications << FactoryBot.create(:authentication, cred)
    end
  end
end
