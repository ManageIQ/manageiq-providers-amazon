class ManageIQ::Providers::Amazon::Inventory::Persister < ManageIQ::Providers::Inventory::Persister
  require_nested :CloudManager
  require_nested :NetworkManager
  require_nested :TargetCollection

  # TODO(lsmola) figure out a way to pass collector info, probably via target, then remove the below
  attr_reader :collector
  # Accessed by cloud parser.
  attr_reader :tag_mapper

  protected

  # TODO: this reads whole table ContainerLabelTagMapping.all.
  #   Is this expensive for each targeted refresh?
  def initialize_tag_mapper
    @tag_mapper = ContainerLabelTagMapping.mapper
    collections[:tags_to_resolve] = @tag_mapper.tags_to_resolve_collection
  end
end
