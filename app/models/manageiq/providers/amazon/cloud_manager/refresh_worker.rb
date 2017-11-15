class ManageIQ::Providers::Amazon::CloudManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner

  # overriding queue_name_for_ems so PerEmsWorkerMixin picks up *all* of the
  # Amazon-manager types from here.
  # This way, the refresher for Amazon's CloudManager will refresh *all*
  # of the Amazon inventory across all managers.
  def self.queue_name_for_ems(ems)
    if ems.kind_of?(ExtManagementSystem)
      queue = ["ems_#{ems.id}"] + ems.child_managers.collect { |manager| "ems_#{manager.id}" }
      queue.sort
    else
      super
    end
  end

  # MiQ complains if this isn't defined
  def queue_name_for_ems(ems)
  end
end
