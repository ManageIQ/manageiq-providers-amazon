class ManageIQ::Providers::Amazon::AgentCoordinatorWorker < MiqWorker
  require_nested :Runner

  include PerEmsWorkerMixin

  self.required_roles = ['smartproxy']

  def self.ems_class
    ManageIQ::Providers::Amazon::CloudManager
  end

  def self.desired_queue_names
    # All cloud managers will share the same agent coordinator
    super.any? ? ["ems_agent_coordinator"] : []
  end
end
