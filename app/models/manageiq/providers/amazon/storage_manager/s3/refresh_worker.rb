class ManageIQ::Providers::Amazon::StorageManager::S3::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.settings_name
    :ems_refresh_worker_amazon_s3
  end
end
