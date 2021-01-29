class ManageIQ::Providers::Amazon::ContainerManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner

  def self.settings_name
    :ems_refresh_worker_amazon_eks
  end
end
