class ManageIQ::Providers::Amazon::Builder
  class << self
    def build_inventory(ems, target)
      case target
      when ManageIQ::Providers::Amazon::CloudManager
        cloud_manager_inventory(ems, target)
      when ManageIQ::Providers::Amazon::NetworkManager
        ManageIQ::Providers::Amazon::Inventory.new(
          ems,
          target,
          :collector_class => ManageIQ::Providers::Amazon::Inventory::Collector::NetworkManager,
          :target_class    => ManageIQ::Providers::Amazon::Inventory::Target::NetworkManager,
          :parsers_classes => [ManageIQ::Providers::Amazon::Inventory::Parser::NetworkManager]
        )
      when ManageIQ::Providers::Amazon::StorageManager::Ebs
        ManageIQ::Providers::Amazon::Inventory.new(
          ems,
          target,
          :collector_class => ManageIQ::Providers::Amazon::Inventory::Collector::StorageManager::Ebs,
          :target_class    => ManageIQ::Providers::Amazon::Inventory::Target::StorageManager::Ebs,
          :parsers_classes => [ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::Ebs]
        )
      when ManageIQ::Providers::Amazon::StorageManager::S3
        ManageIQ::Providers::Amazon::Inventory.new(
          ems,
          target,
          :collector_class => ManageIQ::Providers::Amazon::Inventory::Collector::StorageManager::S3,
          :target_class    => ManageIQ::Providers::Amazon::Inventory::Target::StorageManager::S3,
          :parsers_classes => [ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::S3]
        )
      when ManageIQ::Providers::Amazon::TargetCollection
        ManageIQ::Providers::Amazon::Inventory.new(
          ems,
          target,
          :collector_class => ManageIQ::Providers::Amazon::Inventory::Collector::TargetCollection,
          :target_class    => ManageIQ::Providers::Amazon::Inventory::Target::TargetCollection,
          :parsers_classes => [ManageIQ::Providers::Amazon::Inventory::Parser::CloudManager,
                               ManageIQ::Providers::Amazon::Inventory::Parser::NetworkManager,
                               ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::Ebs]
        )
      else
        # Fallback to ems refresh
        cloud_manager_inventory(ems, target)
      end
    end

    def cloud_manager_inventory(ems, target)
      ::ManageIQ::Providers::Amazon::Inventory.new(
        ems,
        target,
        :collector_class => ManageIQ::Providers::Amazon::Inventory::Collector::CloudManager,
        :target_class    => ManageIQ::Providers::Amazon::Inventory::Target::CloudManager,
        :parsers_classes => [ManageIQ::Providers::Amazon::Inventory::Parser::CloudManager]
      )
    end
  end
end
