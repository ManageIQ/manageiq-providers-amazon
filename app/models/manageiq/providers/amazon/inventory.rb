class ManageIQ::Providers::Amazon::Inventory
  require_nested :Factory
  require_nested :HashCollection
  require_nested :Collectors
  require_nested :Targets
  require_nested :TargetCollection

  attr_reader :ems, :target, :collector, :inventory_collections, :options

  def initialize(ems, target)
    @ems                   = ems
    @target                = target
    @options               = Settings.ems_refresh[ems.class.ems_type]
    @inventory_collections = {:_inventory_collection => true}
    @collector             = initialize_collector

    initialize_inventory_collections
  end
end
