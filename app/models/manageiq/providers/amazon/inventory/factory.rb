class ManageIQ::Providers::Amazon::Inventory::Factory
  class << self
    def inventory(ems, target)
      target(ems, target)
    end

    def target(ems, target)
      case target
      when ManageIQ::Providers::Amazon::CloudManager
        ManageIQ::Providers::Amazon::Inventory::Targets::CloudManager.new(ems, target)
      when ManageIQ::Providers::Amazon::NetworkManager
        ManageIQ::Providers::Amazon::Inventory::Targets::NetworkManager.new(ems, target)
      when ManageIQ::Providers::Amazon::StorageManager::Ebs
        ManageIQ::Providers::Amazon::Inventory::Targets::StorageManager::Ebs.new(ems, target)
      when ManageIQ::Providers::Amazon::StorageManager::S3
        ManageIQ::Providers::Amazon::Inventory::Targets::StorageManager::S3.new(ems, target)
      when ManageIQ::Providers::Amazon::Inventory::EmsEventCollection
        # TODO(lsmola) we need to scan if we've recognized all events and fallback to full refresh if not
        ManageIQ::Providers::Amazon::Inventory::Targets::EmsEventCollection.new(ems, target)
      else
        # Fallback to ems refresh
        ManageIQ::Providers::Amazon::Inventory::Targets::CloudManager.new(ems, ems)
      end
    end
  end
end
