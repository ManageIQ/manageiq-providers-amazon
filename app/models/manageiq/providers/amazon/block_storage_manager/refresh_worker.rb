class ManageIQ::Providers::Amazon::BlockStorageManager::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Amazon::BlockStorageManager
  end

  def self.settings_name
    :ems_refresh_worker_amazon_block_storage
  end
end
