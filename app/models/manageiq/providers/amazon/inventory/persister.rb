class ManageIQ::Providers::Amazon::Inventory::Persister < ManageIQ::Providers::Inventory::Persister
  # TODO(lsmola) figure out a way to pass collector info, probably via target, then remove the below
  attr_reader :collector
end
