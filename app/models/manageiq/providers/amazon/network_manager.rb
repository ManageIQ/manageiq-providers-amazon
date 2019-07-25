class ManageIQ::Providers::Amazon::NetworkManager < ManageIQ::Providers::NetworkManager
  require_nested :CloudNetwork
  require_nested :CloudSubnet
  require_nested :FloatingIp
  require_nested :LoadBalancer
  require_nested :LoadBalancerHealthCheck
  require_nested :LoadBalancerListener
  require_nested :LoadBalancerPool
  require_nested :LoadBalancerPoolMember
  require_nested :NetworkPort
  require_nested :NetworkRouter
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :SecurityGroup

  include ManageIQ::Providers::Amazon::ManagerMixin

  # Auth and endpoints delegations, editing of this type of manager must be disabled
  delegate :authentication_check,
           :authentication_status,
           :authentication_status_ok?,
           :authentications,
           :authentication_for_summary,
           :zone,
           :connect,
           :verify_credentials,
           :with_provider_connection,
           :address,
           :ip_address,
           :hostname,
           :default_endpoint,
           :endpoints,
           :to        => :parent_manager,
           :allow_nil => true

  supports_not :ems_network_new

  def self.ems_type
    @ems_type ||= "ec2_network".freeze
  end

  def self.description
    @description ||= "Amazon EC2 Network".freeze
  end

  def self.hostname_required?
    false
  end

  def self.default_blacklisted_event_names
    %w(
      ConfigurationSnapshotDeliveryCompleted
      ConfigurationSnapshotDeliveryStarted
      ConfigurationSnapshotDeliveryFailed
    )
  end

  def self.display_name(number = 1)
    n_('Network Provider (Amazon)', 'Network Providers (Amazon)', number)
  end

  def inventory_object_refresh?
    true
  end
end
