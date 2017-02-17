class ManageIQ::Providers::Amazon::Inventory < ManagerRefresh::Inventory
  require_nested :Collector
  require_nested :Parser
  require_nested :Persister
end
