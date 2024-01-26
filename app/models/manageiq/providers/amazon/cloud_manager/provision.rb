class ManageIQ::Providers::Amazon::CloudManager::Provision < ManageIQ::Providers::CloudManager::Provision
  include Cloning
  include StateMachine
  include Configuration
end
