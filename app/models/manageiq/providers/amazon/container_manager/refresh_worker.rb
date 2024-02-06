class ManageIQ::Providers::Amazon::ContainerManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  def self.settings_name
    :ems_refresh_worker_amazon_eks
  end
end
