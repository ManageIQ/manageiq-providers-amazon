class ManageIQ::Providers::Amazon::Inventory::Target
  require_nested :CloudManager
  require_nested :NetworkManager
  require_nested :TargetCollection

  attr_reader :collector, :inventory_collections

  delegate :ems, :options, :to => :collector

  def initialize(collector)
    @collector = collector

    @inventory_collections = {}
    initialize_inventory_collections
  end

  protected

  def initialize_inventory_collections
    raise "initialize_inventory_collections must be defined in a subclass"
  end

  def cloud
    ManageIQ::Providers::Amazon::InventoryCollectionDefault::CloudManager
  end

  def network
    ManageIQ::Providers::Amazon::InventoryCollectionDefault::NetworkManager
  end

  def storage
    ManageIQ::Providers::Amazon::InventoryCollectionDefault::StorageManager
  end

  def add_inventory_collection(inventory_collection_data)
    data          = inventory_collection_data
    data[:parent] ||= ems

    if !data.key?(:delete_method) && data[:model_class]
      # Automatically infer what the delete method should be, unless the delete methods was given
      data[:delete_method] = data[:model_class].new.respond_to?(:disconnect_inv) ? :disconnect_inv : nil
    end

    inventory_collections[data[:association]] = ::ManagerRefresh::InventoryCollection.new(data)
  end

  def add_inventory_collections(default, inventory_collections, inventory_collections_data = {})
    inventory_collections.each do |inventory_collection|
      add_inventory_collection(default.send(inventory_collection, inventory_collections_data))
    end
  end

  def add_remaining_inventory_collections(defaults, inventory_collections_data = {})
    defaults.each do |default|
      # Get names of all inventory collections defined in passed classes with Defaults
      all_inventory_collections     = default.methods - ::ManagerRefresh::InventoryCollectionDefault.methods
      # Get names of all defined inventory_collections
      defined_inventory_collections = inventory_collections.keys

      # Add all missing inventory_collections with defined init_data
      add_inventory_collections(default,
                                all_inventory_collections - defined_inventory_collections,
                                inventory_collections_data)
    end
  end

  private

  def event_payload(event)
    transform_keys((event.full_data || []).fetch_path("configurationItem", "configuration"))
  end

  def event_deleted_payload(event)
    transform_keys((event.full_data || []).fetch_path("configurationItemDiff", "changedProperties", "Configuration",
                                                      "previousValue"))
  end

  def transform_keys(value)
    case value
    when Array
      value.map { |x| transform_keys(x) }
    when Hash
      Hash[value.map { |k, v| [k.to_s.underscore, transform_keys(v)] }]
    else
      value
    end
  end
end
