class ManageIQ::Providers::Amazon::StorageManager::S3::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Amazon::StorageManager::S3
  end

  def self.settings_name
    :ems_refresh_worker_amazon_s3
  end
end
