class ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer < ::LoadBalancer
  def self.raw_create_load_balancer(load_balancer_manager, load_balancer_name, options = {})
    load_balancer_manager.with_provider_connection(:service => :ElasticLoadBalancing) do |service|
      _load_balancer = service.client.create_load_balancer(:load_balancer_name => load_balancer_name,
                                                           :listeners          => options[:load_balancer_listeners],
                                                           :subnets            => options[:cloud_subnets],
                                                           :security_groups    => options[:security_groups])
      service.client.register_instances_with_load_balancer(:load_balancer_name => load_balancer_name,
                                                           :instances          => options[:vms])
      service.client.configure_health_check(:load_balancer_name => load_balancer_name,
                                            :health_check       => options[:load_balancer_health_checks].first)
    end
    return load_balancer_name
  rescue => err
    _log.error "load_balancer=[#{load_balancer_name}], error: #{err}"
    raise MiqException::MiqLoadBalancerProvisionError, err.to_s, err.backtrace
  end

  def raw_update_load_balancer(_options)
    raise 'Not supported'
  rescue => err
    _log.error "load_balancer=[#{name}], error: #{err}"
    raise MiqException::MiqLoadBalancerUpdateError, err.to_s, err.backtrace
  end

  def raw_delete_load_balancer
    ext_management_system.with_provider_connection(:service => :ElasticLoadBalancing) do |service|
      service.client.delete_load_balancer(:load_balancer_name => name)
    end
  rescue => err
    _log.error "load_balancer=[#{name}], error: #{err}"
    raise MiqException::MiqLoadBalancerDeleteError, err.to_s, err.backtrace
  end

  def raw_status
    ext_management_system.with_provider_connection(:service => :ElasticLoadBalancing) do |service|
      load_balancer = service.client.describe_load_balancers.load_balancer_descriptions.detect do |x|
        x.load_balancer_name == name
      end
      return 'create_complete' if load_balancer
    end
    raise MiqException::MiqLoadBalancerNotExistError, "Load Balancer #{name} in Provider #{ext_management_system.name} does not exist"
  end

  def raw_exists?
    true
  end
end
