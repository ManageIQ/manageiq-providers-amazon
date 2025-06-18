class ManageIQ::Providers::Amazon::StorageManager::S3 < ManageIQ::Providers::StorageManager
  supports :object_storage

  include ManageIQ::Providers::Amazon::ManagerMixin

  delegate :authentication_check,
           :authentication_status,
           :authentications,
           :authentication_for_summary,
           :verify_credentials,
           :address,
           :ip_address,
           :hostname,
           :default_endpoint,
           :endpoints,
           :cloud_tenants,
           :volume_availability_zones,
           :to        => :parent_manager,
           :allow_nil => true

  virtual_has_many :cloud_tenants
  virtual_has_many :volume_availability_zones

  def self.ems_type
    @ems_type ||= "s3".freeze
  end

  def self.description
    @description ||= "Amazon S3".freeze
  end

  def self.hostname_required?
    false
  end

  def connect(options = {})
    options[:service] = :S3
    parent_manager.connect options
  end
end
