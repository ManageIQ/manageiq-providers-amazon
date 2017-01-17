class ManageIQ::Providers::Amazon::StorageManager::Ebs::RefreshWorker < ::MiqEmsRefreshWorker
  require_nested :Runner

  def self.ems_class
    ManageIQ::Providers::Amazon::StorageManager::Ebs
  end

  def self.settings_name
    :ems_refresh_worker_amazon_block_storage
  end
end
