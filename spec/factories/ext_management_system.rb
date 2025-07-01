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
      client_id  = VcrSecrets.amazon.client_id
      client_key = VcrSecrets.amazon.client_secret

      cred = {
        :userid   => client_id,
        :password => client_key
      }

      ems.authentications << FactoryBot.create(:authentication, cred)
    end
  end

  factory :ems_amazon_eks,
          :aliases => ["manageiq/providers/amazon/container_manager"],
          :class   => "ManageIQ::Providers::Amazon::ContainerManager",
          :parent  => :ems_container do
    provider_region { "us-east-1" }
    security_protocol { "ssl-without-validation" }
    port { 443 }
  end
end
