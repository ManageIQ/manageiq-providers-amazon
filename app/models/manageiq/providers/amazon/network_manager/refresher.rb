module ManageIQ::Providers
  class Amazon::NetworkManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
    include ::EmsRefresh::Refreshers::EmsRefresherMixin

    def parse_legacy_inventory(ems)
      if refresher_options.try(:[], :dto_refresh)
        ManageIQ::Providers::Amazon::NetworkManager::RefreshParserDto.ems_inv_to_hashes(ems, refresher_options)
      else
        ManageIQ::Providers::Amazon::NetworkManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
      end
    end

    def post_process_refresh_classes
      []
    end
  end
end
