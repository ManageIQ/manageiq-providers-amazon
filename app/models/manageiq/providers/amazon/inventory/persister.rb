class ManageIQ::Providers::Amazon::Inventory::Persister < ManageIQ::Providers::Inventory::Persister
  require_nested :CloudManager
  require_nested :NetworkManager
  require_nested :TargetCollection

  # TODO(lsmola) figure out a way to pass collector info, probably via target, then remove the below
  attr_reader :collector
end
