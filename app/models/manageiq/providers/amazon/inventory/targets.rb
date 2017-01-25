class ManageIQ::Providers::Amazon::Inventory::Targets < ManageIQ::Providers::Amazon::Inventory
  require_nested :CloudManager
  require_nested :NetworkManager
  require_nested :EmsEventCollection
  require_nested :TargetCollection

  include ManageIQ::Providers::Amazon::Inventory::InventoryCollectionDefaultInitData

  protected

  def initialize_inventory_collections
    raise "initialize_inventory_collections must be defined in a subclass"
  end

  def add_inventory_collection(inventory_collection_data, key = nil)
    model_class, data = inventory_collection_data
    data[:parent]     ||= ems
    key               ||= data[:association]

    inventory_collections[key] = ::ManagerRefresh::InventoryCollection.new(model_class, data)
  end

  def add_inventory_collections(inventory_collections, inventory_collections_data = {})
    inventory_collections.each do |inventory_collection|
      add_inventory_collection(send("#{inventory_collection}_init_data", inventory_collections_data))
    end
  end

  def add_remaining_inventory_collections(inventory_collections_data)
    # Get names of all inventory collections defined in InventoryCollectionDefaultInitData
    all_inventory_collections     = ManageIQ::Providers::Amazon::Inventory::InventoryCollectionDefaultInitData
      .public_instance_methods.grep(/.+_init_data/).map { |x| x.to_s.gsub("_init_data", "") }
    # Get names of all defined inventory_collections
    defined_inventory_collections = inventory_collections.keys.map(&:to_s)

    # Add all missing inventory_collections with defined init_data
    add_inventory_collections(all_inventory_collections - defined_inventory_collections,
                              inventory_collections_data)
  end

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
