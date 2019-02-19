module ManageIQ::Providers
  class Amazon::StorageManager::S3::Refresher < ManageIQ::Providers::BaseManager::Refresher
    # Legacy parse
    #
    # @param ems [ManageIQ::Providers::BaseManager]
    def parse_legacy_inventory(ems)
      ::ManageIQ::Providers::Amazon::StorageManager::S3::RefreshParser.ems_inv_to_hashes(ems)
    end

    def post_process_refresh_classes
      []
    end
  end
end
