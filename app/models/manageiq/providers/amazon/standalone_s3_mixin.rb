module ManageIQ::Providers::Amazon::StandaloneS3Mixin
  extend ActiveSupport::Concern

  included do
    before_create :match_manager_group
    after_create :ensure_s3_storage_manager
    before_destroy :remove_s3_storage_manager
  end

  # connect clound manager with other cloud managers that use same userid/password
  # (S3 manager is shared within manager_group)
  def match_manager_group
    return unless default_authentication

    matching_manager = ManageIQ::Providers::Amazon::CloudManager.joins(:authentications).find_by(
      "userid = :id", :id => default_authentication.userid
    )
    self.manager_group = matching_manager.manager_group if matching_manager
  end

  # obtain storage manager that belongs to my manager_group
  def s3_storage_manager
    ManageIQ::Providers::Amazon::StorageManager::S3.find_by(:manager_group => manager_group)
  end

  # create storage manager for this manager_group if not exist
  def ensure_s3_storage_manager
    return if s3_storage_manager

    manager = ManageIQ::Providers::Amazon::StorageManager::S3.new(
      :name            => "S3 Storage Manager (#{manager_group})",
      :zone_id         => zone_id,
      :manager_group   => manager_group,
      :parent_ems_id   => nil,
      :provider_region => provider_region # TODO: S3 is region agnostic
    )

    # Duplicate endpoint and authentication from CloudManager
    manager.endpoints << default_endpoint.dup
    manager.authentications << default_authentication.dup if default_authentication

    manager.save!
  end

  # replicate cloud manager authentication updates on S3
  def after_update_authentication
    cred = default_authentication
    manager = s3_storage_manager
    manager.update_authentication(:default => {:userid => cred.userid, :password => cred.password}) if manager
  end

  # remove S3 manager together with last cloud manager
  def remove_s3_storage_manager
    manager = s3_storage_manager
    return unless manager

    if ManageIQ::Providers::Amazon::CloudManager.where(:manager_group => manager_group).count == 1
      manager.delete
    end
  end

  # manually add s3 manager to list of storage managers
  def storage_managers
    manager = s3_storage_manager
    if manager
      super << manager
    else
      super
    end
  end
end
