require Rails.root.join('spec/shared/controllers/shared_ems_network_controller_spec')

describe EmsNetworkController do
  include_examples :ems_network_controller_spec, %w(amazon)
end
