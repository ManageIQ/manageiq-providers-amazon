module ManageIQ::Providers
  class Amazon::StorageManager::Ebs::Refresher < ManageIQ::Providers::BaseManager::Refresher
    def parse_legacy_inventory(ems)
      ::ManageIQ::Providers::Amazon::StorageManager::Ebs::RefreshParser.ems_inv_to_hashes(ems)
    end

    def post_process_refresh_classes
      []
    end
  end
end
