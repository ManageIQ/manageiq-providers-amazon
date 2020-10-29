class ManageIQ::Providers::Amazon::ContainerManager < ManageIQ::Providers::Kubernetes::ContainerManager
  require_nested :ContainerGroup
end
