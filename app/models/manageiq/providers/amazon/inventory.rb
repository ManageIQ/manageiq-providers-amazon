class ManageIQ::Providers::Amazon::Inventory < ManageIQ::Providers::Inventory
  require_nested :Collector
  require_nested :Parser
  require_nested :Persister

  # Default manager for building collector/parser/persister classes
  # when failed to get class name from refresh target automatically
  def self.default_manager_name
    "CloudManager"
  end

  def self.parser_classes_for(ems, target)
    case target
    when ManagerRefresh::TargetCollection
      [ManageIQ::Providers::Amazon::Inventory::Parser::CloudManager,
       ManageIQ::Providers::Amazon::Inventory::Parser::NetworkManager,
       ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::Ebs]
    else
      super
    end
  end

end
