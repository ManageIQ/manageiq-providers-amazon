class ManageIQ::Providers::Amazon::Builder
  class << self
    def build_inventory(ems, target)
      case target
      when ManageIQ::Providers::Amazon::CloudManager
        cloud_manager_inventory(ems, target)
      when ManageIQ::Providers::Amazon::NetworkManager
        inventory(
          ems,
          target,
          ManageIQ::Providers::Amazon::Inventory::Collector::NetworkManager,
          ManageIQ::Providers::Amazon::Inventory::Persister::NetworkManager,
          [ManageIQ::Providers::Amazon::Inventory::Parser::NetworkManager]
        )
      when ManageIQ::Providers::Amazon::StorageManager::Ebs
        inventory(
          ems,
          target,
          ManageIQ::Providers::Amazon::Inventory::Collector::StorageManager::Ebs,
          ManageIQ::Providers::Amazon::Inventory::Persister::StorageManager::Ebs,
          [ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::Ebs]
        )
      when ManageIQ::Providers::Amazon::StorageManager::S3
        inventory(
          ems,
          target,
          ManageIQ::Providers::Amazon::Inventory::Collector::StorageManager::S3,
          ManageIQ::Providers::Amazon::Inventory::Persister::StorageManager::S3,
          [ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::S3]
        )
      when ManageIQ::Providers::Amazon::TargetCollection
        inventory(
          ems,
          target,
          ManageIQ::Providers::Amazon::Inventory::Collector::TargetCollection,
          ManageIQ::Providers::Amazon::Inventory::Persister::TargetCollection,
          [ManageIQ::Providers::Amazon::Inventory::Parser::CloudManager,
           ManageIQ::Providers::Amazon::Inventory::Parser::NetworkManager,
           ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::Ebs]
        )
      else
        # Fallback to ems refresh
        cloud_manager_inventory(ems, target)
      end
    end

    private

    def cloud_manager_inventory(ems, target)
      inventory(
        ems,
        target,
        ManageIQ::Providers::Amazon::Inventory::Collector::CloudManager,
        ManageIQ::Providers::Amazon::Inventory::Persister::CloudManager,
        [ManageIQ::Providers::Amazon::Inventory::Parser::CloudManager]
      )
    end

    def inventory(manager, raw_target, collector_class, persister_class, parsers_classes)
      collector = collector_class.new(manager, raw_target)
      # TODO(lsmola) figure out a way to pass collector info, probably via target
      persister = persister_class.new(manager, raw_target, collector)

      ::ManageIQ::Providers::Amazon::Inventory.new(
        persister,
        collector,
        parsers_classes.map(&:new)
      )
    end
  end
end
