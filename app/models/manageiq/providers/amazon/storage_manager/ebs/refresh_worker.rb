class ManageIQ::Providers::Amazon::StorageManager::Ebs::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.settings_name
    :ems_refresh_worker_amazon_ebs_storage
  end
end
