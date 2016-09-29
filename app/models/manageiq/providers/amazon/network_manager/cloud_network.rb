class ManageIQ::Providers::Amazon::NetworkManager::CloudNetwork < ::CloudNetwork
  include DtoMixin

  dto_attributes :type, :ems_ref, :name, :cidr ,:status,:enabled, :orchestration_stack, :cloud_subnets
end
