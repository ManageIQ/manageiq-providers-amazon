class ManageIQ::Providers::Amazon::StorageManager::Ebs < ManageIQ::Providers::StorageManager
  require_nested :CloudVolume
  require_nested :CloudVolumeSnapshot
  require_nested :Refresher

  include ManageIQ::Providers::Amazon::ManagerMixin

  delegate :availability_zones,
           :authentication_check,
           :authentication_status,
           :authentications,
           :authentication_for_summary,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :address,
           :ip_address,
           :hostname,
           :default_endpoint,
           :endpoints,
           :cloud_tenants,
           :volume_availability_zones,
           :to        => :parent_manager,
           :allow_nil => true

  virtual_delegate :cloud_tenants, :to => :parent_manager, :allow_nil => true
  virtual_delegate :volume_availability_zones, :to => :parent_manager, :allow_nil => true

  supports :block_storage
  supports :cloud_volume
  supports :cloud_volume_create

  def self.ems_type
    @ems_type ||= "ec2_ebs_storage".freeze
  end

  def self.description
    @description ||= "Amazon EBS".freeze
  end

  def self.hostname_required?
    false
  end

  def self.display_name(number = 1)
    n_('Elastic Block Storage Manager (Amazon)', 'Elastic Block Storage Managers (Amazon)', number)
  end
end
