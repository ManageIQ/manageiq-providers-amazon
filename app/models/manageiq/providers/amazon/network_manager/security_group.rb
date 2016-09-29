class ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup < ::SecurityGroup
  include DtoMixin
  dto_dependencies :cloud_network, :orchestration_stack
  dto_attributes :type, :ems_ref, :name, :description, :cloud_network, :orchestration_stack
end
