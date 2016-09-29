class ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer < ::LoadBalancer
  include DtoMixin
  dto_attributes :type, :ems_ref, :name
end
