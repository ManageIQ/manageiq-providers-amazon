class ManageIQ::Providers::Amazon::Inventory::Collector::ContainerManager < ManageIQ::Providers::Kubernetes::Inventory::Collector::ContainerManager
  require_nested :WatchNotice
end
