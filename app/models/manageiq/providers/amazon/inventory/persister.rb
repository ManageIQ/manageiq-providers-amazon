class ManageIQ::Providers::Amazon::Inventory::Persister < ManagerRefresh::Inventory::Persister
  require_nested :CloudManager
  require_nested :NetworkManager
  require_nested :TargetCollection

  protected

  def cloud
    ManageIQ::Providers::Amazon::InventoryCollectionDefault::CloudManager
  end

  def network
    ManageIQ::Providers::Amazon::InventoryCollectionDefault::NetworkManager
  end

  def storage
    ManageIQ::Providers::Amazon::InventoryCollectionDefault::StorageManager
  end
end
