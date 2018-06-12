class ManageIQ::Providers::Amazon::Inventory::Persister < ManagerRefresh::Inventory::Persister
  require_nested :CloudManager
  require_nested :NetworkManager
  require_nested :TargetCollection

  # TODO(lsmola) figure out a way to pass collector info, probably via target, then remove the below
  attr_reader :collector
  # Accessed by cloud parser.
  attr_reader :tag_mapper

  # @param manager [ManageIQ::Providers::BaseManager] A manager object
  # @param target [Object] A refresh Target object
  # @param collector [ManagerRefresh::Inventory::Collector] A Collector object
  def initialize(manager, target = nil, collector = nil)
    @manager   = manager
    @target    = target
    @collector = collector

    @collections = {}

    initialize_inventory_collections
  end

  protected

  # TODO: this reads whole table ContainerLabelTagMapping.all.
  #   Is this expensive for each targeted refresh?
  def initialize_tag_mapper
    @tag_mapper = ContainerLabelTagMapping.mapper
    collections[:tags_to_resolve] = @tag_mapper.tags_to_resolve_collection
  end

  def strategy
    nil
  end

  def parent
    manager.presence
  end

  def shared_options
    {
      :strategy => strategy,
      :targeted => targeted?,
      :parent   => parent
    }
  end
end
