class ManageIQ::Providers::Amazon::Inventory::Parser < ManagerRefresh::Inventory::Parser
  require_nested :CloudManager
  require_nested :NetworkManager

  include ManageIQ::Providers::Amazon::ParserHelperMethods

  def process_inventory_collection(collection, key)
    (collection || []).each do |item|
      new_result = yield(item)
      next if new_result.blank?

      raise "InventoryCollection #{key} must be defined" unless persister.collections[key]

      persister.collections[key] << persister.collections[key].new_inventory_object(new_result)
    end
  end
end
