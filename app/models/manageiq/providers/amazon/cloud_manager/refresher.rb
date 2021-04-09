class ManageIQ::Providers::Amazon::CloudManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
  # List classes that will have post process method invoked
  def post_process_refresh_classes
    [::Vm]
  end
end
