class ManageIQ::Providers::Amazon::AgentCoordinatorWorker < MiqWorker
  require_nested :Runner

  include PerEmsWorkerMixin

  self.required_roles = ['smartproxy']

  def self.desired_queue_names
    return [] if MiqServer.minimal_env? && !self.has_minimal_env_option?
    cloud_managers = all_valid_ems_in_zone.collect { |e| e.kind_of?(ManageIQ::Providers::Amazon::CloudManager) }

    # All cloud managers will share the same agent coordinator
    cloud_managers.any? ? ["ems_agent_coordinator"] : []
  end
end
