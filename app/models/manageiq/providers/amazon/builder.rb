class ManageIQ::Providers::Amazon::Builder < ManageIQ::Providers::Inventory::Builder
  class << self
    def build_inventory(ems, target)
      case target
      when ManageIQ::Providers::Amazon::StorageManager::Ebs
        build_storage_ebs_inventory(ems, target)
      when ManageIQ::Providers::Amazon::StorageManager::S3
        build_storage_s3_inventory(ems, target)
      when ManagerRefresh::TargetCollection
        build_target_collection_inventory(ems, target)
      else
        super
      end
    end

    private

    def build_storage_ebs_inventory(ems, target)
      inventory(
        ems,
        target,
        ManageIQ::Providers::Amazon::Inventory::Collector::StorageManager::Ebs,
        ManageIQ::Providers::Amazon::Inventory::Persister::StorageManager::Ebs,
        [ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::Ebs]
      )
    end

    def build_storage_s3_inventory(ems, target)
      inventory(
        ems,
        target,
        ManageIQ::Providers::Amazon::Inventory::Collector::StorageManager::S3,
        ManageIQ::Providers::Amazon::Inventory::Persister::StorageManager::S3,
        [ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::S3]
      )
    end

    def build_target_collection_inventory(ems, target)
      inventory(
        ems,
        target,
        ManageIQ::Providers::Amazon::Inventory::Collector::TargetCollection,
        ManageIQ::Providers::Amazon::Inventory::Persister::TargetCollection,
        [ManageIQ::Providers::Amazon::Inventory::Parser::CloudManager,
         ManageIQ::Providers::Amazon::Inventory::Parser::NetworkManager,
         ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::Ebs]
      )
    end

    def allowed_manager_types
      %w(Cloud Network Storage)
    end
  end
end
