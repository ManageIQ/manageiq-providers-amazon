class ManageIQ::Providers::Amazon::CloudManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
  # Saves the inventory to the DB
  #
  # @param ems [ManageIQ::Providers::BaseManager] Manager owning the refresh
  # @param target [ManageIQ::Providers::BaseManager or InventoryRefresh::Target or InventoryRefresh::TargetCollection]
  #        Target we are refreshing
  # @param _hashes_or_persister [Array<Hash> or ManageIQ::Providers::Inventory::Persister] Used in superclass
  def save_inventory(ems, target, _hashes_or_persister)
    super

    EmsRefresh.queue_refresh(ems.network_manager) if target.kind_of?(ManageIQ::Providers::BaseManager)
    EmsRefresh.queue_refresh(ems.ebs_storage_manager) if target.kind_of?(ManageIQ::Providers::BaseManager)
  end

  # List classes that will have post process method invoked
  def post_process_refresh_classes
    [::Vm]
  end
end
