class ManageIQ::Providers::Amazon::Inventory::Persister < ManagerRefresh::Inventory::Persister
  require_nested :CloudManager
  require_nested :NetworkManager
  require_nested :TargetCollection

  # TODO(lsmola) figure out a way to pass collector info, probably via target, then remove the below
  attr_reader :collector
  # @param manager [ManageIQ::Providers::BaseManager] A manager object
  # @param target [Object] A refresh Target object
  # @param target [ManagerRefresh::Inventory::Collector] A Collector object
  def initialize(manager, target = nil, collector = nil)
    @manager   = manager
    @target    = target
    @collector = collector

    @collections = {}

    initialize_inventory_collections
  end

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

  def targeted
    false
  end

  def strategy
    nil
  end

  def check_changed
    true
  end

  def shared_options
    settings_options = options[:inventory_collections].try(:to_hash) || {}

    settings_options.merge(
      :strategy      => strategy,
      :targeted      => targeted,
      :check_changed => check_changed
    )
  end
end
