class ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerServiceOptionConverter < ::ServiceLoadBalancer::OptionConverter
  def load_balancer_create_options
    {
      :load_balancer_listeners     => self.class.load_balancer_listeners(dialog_options),
      :cloud_subnets               => self.class.cloud_subnets(dialog_options),
      :security_groups             => self.class.security_groups(dialog_options),
      :vms                         => self.class.vms(dialog_options),
      :load_balancer_health_checks => self.class.load_balancer_health_checks(dialog_options),
    }
  end
end
