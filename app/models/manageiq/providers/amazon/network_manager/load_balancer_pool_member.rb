class ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPoolMember < ::LoadBalancerPoolMember
  include DtoMixin
  dto_attributes :type, :ems_ref, :vm
end
