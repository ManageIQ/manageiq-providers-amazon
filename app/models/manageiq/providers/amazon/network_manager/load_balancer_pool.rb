class ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPool < ::LoadBalancerPool
  include DtoMixin
  dto_attributes :type, :ems_ref, :name
end
