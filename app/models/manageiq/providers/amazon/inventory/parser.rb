class ManageIQ::Providers::Amazon::Inventory::Parser < ManageIQ::Providers::Inventory::Parser
  require_nested :CloudManager
  require_nested :NetworkManager

  include ManageIQ::Providers::Amazon::ParserHelperMethods

  # Overridden helper methods, we should put them in helper once we get rid of old refresh
  def get_from_tags(resource, tag_name)
    tag_name = tag_name.to_s.downcase
    Array.wrap(resource['tags']).detect { |tag, _| tag['key'].downcase == tag_name }.try(:[], 'value').presence
  end
end
