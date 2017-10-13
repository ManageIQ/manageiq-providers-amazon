module ManageIQ::Providers
  class Amazon::NetworkManager::Refresher < ManageIQ::Providers::BaseManager::ManagerRefresher
    def post_process_refresh_classes
      []
    end
  end
end
