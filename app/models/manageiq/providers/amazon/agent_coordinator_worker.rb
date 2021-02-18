class ManageIQ::Providers::Amazon::AgentCoordinatorWorker < MiqWorker
  include ProviderWorkerMixin
  include MiqWorker::ReplicaPerWorker

  require_nested :Runner

  self.required_roles = ['smartproxy']
  self.workers        = 1

  def self.has_required_role?
    super && all_valid_ems_in_zone.any?
  end

  def self.ems_class
    ManageIQ::Providers::Amazon::CloudManager
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_REFRESH_WORKERS
  end
end
