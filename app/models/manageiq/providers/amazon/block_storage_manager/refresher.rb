class ManageIQ::Providers::Amazon::BlockStorageManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
  include ::EmsRefresh::Refreshers::EmsRefresherMixin

  def parse_legacy_inventory(ems)
    ManageIQ::Providers::Amazon::BlockStorageManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
  end
end
