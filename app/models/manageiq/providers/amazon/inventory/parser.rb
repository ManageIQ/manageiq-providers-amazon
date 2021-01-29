class ManageIQ::Providers::Amazon::Inventory::Parser < ManageIQ::Providers::Inventory::Parser
  require_nested :CloudManager
  require_nested :ContainerManager
  require_nested :NetworkManager

  include ManageIQ::Providers::Amazon::ParserHelperMethods

  # Overridden helper methods, we should put them in helper once we get rid of old refresh
  def get_from_tags(resource, tag_name)
    tag_name = tag_name.to_s.downcase
    tags = resource['tags'].to_a.concat(resource['tag_set'].to_a)
    Array.wrap(tags).detect { |tag, _| tag['key'].downcase == tag_name }.try(:[], 'value').presence
  end
end
