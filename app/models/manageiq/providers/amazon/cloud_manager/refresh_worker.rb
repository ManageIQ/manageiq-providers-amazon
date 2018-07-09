class ManageIQ::Providers::Amazon::CloudManager::RefreshWorker < ManageIQ::Providers::BaseManager::RefreshWorker
  require_nested :Runner

  # overriding queue_name_for_ems so PerEmsWorkerMixin picks up *all* of the
  # Amazon-manager types from here.
  # This way, the refresher for Amazon's CloudManager will refresh *all*
  # of the Amazon inventory across all managers.
  class << self
    def queue_name_for_ems(ems)
      return ems unless ems.kind_of?(ExtManagementSystem)
      combined_managers(ems).collect(&:queue_name).sort
    end

    private

    def combined_managers(ems)
      child_managers = ems.child_managers.reject do |child_ems|
        child_ems.kind_of?(ManageIQ::Providers::Amazon::StorageManager::S3)
      end
      [ems].concat(child_managers)
    end
  end

  # MiQ complains if this isn't defined
  def queue_name_for_ems(ems)
  end
end
