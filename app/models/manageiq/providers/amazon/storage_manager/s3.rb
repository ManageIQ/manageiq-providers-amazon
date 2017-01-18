class ManageIQ::Providers::Amazon::StorageManager::S3 < ManageIQ::Providers::StorageManager
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher

  include ManageIQ::Providers::Amazon::ManagerMixin
  include ManageIQ::Providers::StorageManager::ObjectMixin

  delegate :authentication_check,
           :authentication_status,
           :authentications,
           :authentication_for_summary,
           :zone,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :address,
           :ip_address,
           :hostname,
           :default_endpoint,
           :endpoints,
           :to        => :parent_manager,
           :allow_nil => true

  def self.ems_type
    @ems_type ||= "s3".freeze
  end

  def self.description
    @description ||= "Amazon S3".freeze
  end

  def self.hostname_required?
    false
  end
end
