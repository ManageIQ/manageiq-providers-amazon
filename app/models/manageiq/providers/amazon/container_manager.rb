class ManageIQ::Providers::Amazon::ContainerManager < ManageIQ::Providers::Kubernetes::ContainerManager
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :Refresher
  require_nested :RefreshWorker

  def self.ems_type
    @ems_type ||= "eks".freeze
  end

  def self.description
    @description ||= "Amazon EKS".freeze
  end
end
