class ManageIQ::Providers::Amazon::StorageManager::S3::Refresher <
  ManageIQ::Providers::BaseManager::Refresher
  include ::EmsRefresh::Refreshers::EmsRefresherMixin

  def parse_legacy_inventory(ems)
    ManageIQ::Providers::Amazon::StorageManager::S3::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
  end
end
