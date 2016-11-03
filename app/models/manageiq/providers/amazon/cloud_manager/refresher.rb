class ManageIQ::Providers::Amazon::CloudManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
  include ::EmsRefresh::Refreshers::EmsRefresherMixin

  def parse_legacy_inventory(ems)
    if refresher_options.try(:[], :dto_refresh)
      ManageIQ::Providers::Amazon::CloudManager::RefreshParserDto.ems_inv_to_hashes(ems, refresher_options)
    else
      ManageIQ::Providers::Amazon::CloudManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
    end
  end

  # TODO(lsmola) NetworkManager, remove this once we have a full representation of the NetworkManager.
  # NetworkManager should refresh base on its own conditions
  def save_inventory(ems, _targets, hashes)
    EmsRefresh.save_ems_inventory(ems, hashes)
    EmsRefresh.queue_refresh(ems.network_manager)
  end

  def post_process_refresh_classes
    [::Vm]
  end
end
