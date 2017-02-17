class ManageIQ::Providers::Amazon::Provider < ::Provider
  include ConnectionConfigurationMixin
  include ManageIQ::Providers::Amazon::ProviderMixin

  has_many :endpoints, :as => :resource, :dependent => :destroy, :autosave => true

  has_many :cloud_managers,
           :foreign_key => :provider_id,
           :class_name  => "ManageIQ::Providers::Amazon::CloudManager",
           :autosave    => true,
           :dependent   => :destroy

  has_one :s3_storage_manager,
          :foreign_key => :provider_id,
          :class_name  => "ManageIQ::Providers::Amazon::StorageManager::S3",
          :autosave    => true,
          :dependent   => :destroy

  before_create :ensure_managers

  def ensure_managers
    build_s3_storage_manager unless s3_storage_manager
    s3_storage_manager.name            = "S3 Storage Manager for #{name}"
    s3_storage_manager.zone_id         = zone_id
    s3_storage_manager.provider_region = "us-east-1" # TODO: S3 is region agnostic
  end

  def cloud_manager_for_region(provider_region)
    cloud_managers.find{|el| el.provider_region == provider_region}
  end

  def provider_regions=(x)
    ensure_managers_for_regions x
  end

  def provider_regions
    cloud_managers.pluck(:provider_region)
  end

  def ensure_managers_for_regions(provider_regions)
    provider_regions.each do |provider_region|
      ensure_managers_for_region(provider_region)
    end

    # remove managers for other regions
    obsolete_managers = cloud_managers.select{|el| !provider_regions.include? el.provider_region}
    obsolete_managers.each do |el|
      cloud_managers.delete(el)
      el.destroy
    end
  end

  def ensure_managers_for_region(provider_region)
    if cloud_manager_for_region(provider_region).nil?
      cloud_manager = ManageIQ::Providers::Amazon::CloudManager.new
      cloud_manager.name            = "#{name} - EC2 (#{provider_region})"
      cloud_manager.zone_id         = zone_id
      cloud_manager.provider_region = provider_region
      cloud_managers << cloud_manager
    end
  end

  def supports_authentication?(authtype)
    authtype.to_s == "default"
  end
end
