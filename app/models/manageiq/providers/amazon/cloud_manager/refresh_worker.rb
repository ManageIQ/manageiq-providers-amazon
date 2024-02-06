class ManageIQ::Providers::Amazon::CloudManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  def self.combined_managers(ems)
    super.reject { |e| e.kind_of?(ManageIQ::Providers::Amazon::StorageManager::S3) }
  end
end
