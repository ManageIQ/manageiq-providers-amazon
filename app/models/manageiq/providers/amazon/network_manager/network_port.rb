class ManageIQ::Providers::Amazon::NetworkManager::NetworkPort < ::NetworkPort
  include DtoMixin

  dto_attributes :type, :name, :ems_ref, :status, :mac_address, :device_owner, :device_ref, :device, :cloud_subnet_network_ports, :security_groups
end
