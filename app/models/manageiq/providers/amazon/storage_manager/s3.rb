class ManageIQ::Providers::Amazon::StorageManager::S3 < ManageIQ::Providers::StorageManager
  require_nested :CloudObjectStoreContainer
  require_nested :CloudObjectStoreObject
  require_nested :RefreshWorker
  require_nested :Refresher

  supports :cloud_object_store_container_create

  include ManageIQ::Providers::Amazon::ManagerMixin
  include ManageIQ::Providers::StorageManager::ObjectMixin

  delegate :authentication_check,
           :authentication_status,
           :authentications,
           :authentication_for_summary,
           :zone,
           :verify_credentials,
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

  def inventory_object_refresh?
    true
  end

  def connect(options = {})
    options[:service] = :S3
    parent_manager.connect options
  end
end
