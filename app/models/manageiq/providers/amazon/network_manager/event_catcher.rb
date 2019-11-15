class ManageIQ::Providers::Amazon::NetworkManager::EventCatcher < ::MiqEventCatcher
  def self.settings_name
    :event_catcher_amazon_network
  end
end
