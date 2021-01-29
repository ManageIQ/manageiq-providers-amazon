class ManageIQ::Providers::Amazon::ContainerManager::EventCatcher < ManageIQ::Providers::BaseManager::EventCatcher
  require_nested :Runner

  def self.settings_name
    :event_catcher_amazon_eks
  end
end
