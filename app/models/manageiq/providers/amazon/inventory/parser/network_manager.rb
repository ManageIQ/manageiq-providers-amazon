class ManageIQ::Providers::Amazon::Inventory::Parser::NetworkManager < ManageIQ::Providers::Amazon::Inventory::Parser
  def ems
    collector.manager.respond_to?(:network_manager) ? collector.manager.network_manager : collector.manager
  end

  def parse
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{collector.manager.name}] id: [#{collector.manager.id}]"

    $aws_log.info("#{log_header}...")
    # The order of the below methods doesn't matter since they refer to each other using only lazy links
    cloud_networks
    cloud_subnets
    security_groups
    get_network_ports
    load_balancers
    get_ec2_floating_ips_and_ports
    get_floating_ips
    $aws_log.info("#{log_header}...Complete")
  end

  private

  def cloud_networks
    collector.cloud_networks.each do |vpc|
      uid    = vpc['vpc_id']
      name   = get_from_tags(vpc, 'name')
      name   ||= uid
      status = vpc['state'] == :available ? "active" : "inactive"

      persister_network = persister.cloud_networks.find_or_build(uid)
      persister_network.assign_attributes(
        :type                  => self.class.cloud_network_type.name,
        :ext_management_system => ems,
        :ems_ref               => uid,
        :name                  => name,
        :cidr                  => vpc['cidr_block'],
        :status                => status,
        :enabled               => true,
        :orchestration_stack   => persister.orchestration_stacks.lazy_find(
          get_from_tags(vpc, "aws:cloudformation:stack-id")
        ),
      )
    end
  end

  def cloud_subnets
    collector.cloud_subnets.each do |subnet|
      uid  = subnet['subnet_id']
      name = get_from_tags(subnet, 'name')
      name ||= uid

      persister_subnet = persister.cloud_subnets.find_or_build(uid)
      persister_subnet.assign_attributes(
        :type                  => self.class.cloud_subnet_type.name,
        :ext_management_system => ems,
        :ems_ref               => uid,
        :name                  => name,
        :cidr                  => subnet['cidr_block'],
        :status                => subnet['state'].try(:to_s),
        :availability_zone     => persister.availability_zones.lazy_find(subnet['availability_zone']),
        :cloud_network         => persister.cloud_networks.lazy_find(subnet['vpc_id']),
      )
    end
  end

  def security_groups
    collector.security_groups.each do |sg|
      uid = sg['group_id']

      persister_security_group = persister.security_groups.find_or_build(uid)
      persister_security_group.assign_attributes(
        :type                  => self.class.security_group_type.name,
        :ext_management_system => ems,
        :ems_ref               => uid,
        :name                  => sg['group_name'],
        :description           => sg['description'].try(:truncate, 255),
        :cloud_network         => persister.cloud_networks.lazy_find(sg['vpc_id']),
        :orchestration_stack   => persister.orchestration_stacks.lazy_find(
          get_from_tags(sg, "aws:cloudformation:stack-id")
        ),
      )

      sg['ip_permissions'].each { |perm| firewall_rule(persister_security_group, perm, "inbound") }
      sg['ip_permissions_egress'].each { |perm| firewall_rule(persister_security_group,perm, "outbound") }
    end
  end

  # TODO: Should ICMP protocol values have their own 2 columns, or
  #   should they override port and end_port like the Amazon API.
  def firewall_rule(persister_security_group, perm, direction)
    common = {
      :direction     => direction,
      :host_protocol => perm['ip_protocol'].to_s.upcase,
      :port          => perm['from_port'],
      :end_port      => perm['to_port'],
      :resource      => persister_security_group
    }

    (perm['user_id_group_pairs'] || []).each do |g|
      firewall_rule                   = common.dup
      firewall_rule[:source_security_group] = persister.security_groups.lazy_find(g['group_id'])
      persister.firewall_rules.build(firewall_rule)
    end

    (perm['ip_ranges'] || []).each do |r|
      firewall_rule                   = common.dup
      firewall_rule[:source_ip_range] = r['cidr_ip']
      persister.firewall_rules.build(firewall_rule)
    end
  end

  def load_balancers
    collector.load_balancers.each do |lb|
      uid = lb['load_balancer_name']

      persister_load_balancer = persister.load_balancers.find_or_build(uid)
      persister_load_balancer.assign_attributes(
        :type                  => self.class.load_balancer_type.name,
        :ext_management_system => ems,
        :ems_ref               => uid,
        :name                  => uid,
      )

      persister_load_balancer_pool = persister.load_balancer_pools.find_or_build(uid)
      persister_load_balancer_pool.assign_attributes(
        :type                  => self.class.load_balancer_pool_type.name,
        :ext_management_system => ems,
        :ems_ref               => uid,
        :name                  => uid,
      )

      load_balancer_pool_members(persister_load_balancer_pool, lb['instances'])
      load_balancer_listeners(persister_load_balancer, persister_load_balancer_pool, lb)
      load_balancer_health_checks(persister_load_balancer, uid, lb['health_check'])
    end
  end

  def load_balancer_pool_members(persister_load_balancer_pool, members)
    members.each do |member|
      uid = member['instance_id']

      persister_load_balancer_pool_member = persister.load_balancer_pool_members.find_or_build(uid)
      persister_load_balancer_pool_member.assign_attributes(
        :type                  => self.class.load_balancer_pool_member_type.name,
        :ext_management_system => ems,
        :ems_ref               => uid,
        # TODO(lsmola) AWS always associates to eth0 of the instances, we do not collect that info now, we need to do that
        # :network_port => get eth0 network_port
        :vm                    => persister.vms.lazy_find(uid)
      )

      persister.load_balancer_pool_member_pools.find_or_build_by(
        :load_balancer_pool        => persister_load_balancer_pool,
        :load_balancer_pool_member => persister_load_balancer_pool_member
      )
    end
  end

  def load_balancer_listeners(persister_load_balancer, persister_load_balancer_pool, lb)
    lb['listener_descriptions'].each do |listener|
      listener = listener['listener']
      uid      = "#{lb['load_balancer_name']}__#{listener['protocol']}__#{listener['load_balancer_port']}__"\
                 "#{listener['instance_protocol']}__#{listener['instance_port']}__#{listener['ssl_certificate_id']}"

      persister_load_balancer_listener = persister.load_balancer_listeners.find_or_build(uid)
      persister_load_balancer_listener.assign_attributes(
        :type                     => self.class.load_balancer_listener_type.name,
        :ext_management_system    => ems,
        :ems_ref                  => uid,
        :load_balancer_protocol   => listener['protocol'],
        :load_balancer_port_range => (listener['load_balancer_port'].to_i..listener['load_balancer_port'].to_i),
        :instance_protocol        => listener['instance_protocol'],
        :instance_port_range      => (listener['instance_port'].to_i..listener['instance_port'].to_i),
        :load_balancer            => persister_load_balancer,
      )

      persister.load_balancer_listener_pools.find_or_build_by(
        :load_balancer_listener => persister_load_balancer_listener,
        :load_balancer_pool     => persister_load_balancer_pool
      )
    end
  end

  def load_balancer_health_checks(persister_load_balancer, uid, health_check)
    target_match = health_check['target'].match(/^(\w+)\:(\d+)\/?(.*?)$/)
    protocol     = target_match[1]
    port         = target_match[2].to_i
    url_path     = target_match[3]

    persister_load_balancer_health_check = persister.load_balancer_health_checks.find_or_build(uid)
    persister_load_balancer_health_check.assign_attributes(
      :type                  => self.class.load_balancer_health_check_type.name,
      :ext_management_system => ems,
      :ems_ref               => uid,
      :protocol              => protocol,
      :port                  => port,
      :url_path              => url_path,
      :interval              => health_check['interval'],
      :timeout               => health_check['timeout'],
      :unhealthy_threshold   => health_check['unhealthy_threshold'],
      :healthy_threshold     => health_check['healthy_threshold'],
      :load_balancer         => persister_load_balancer,
    )

    load_balancer_health_checks_members(persister_load_balancer_health_check, uid)
  end

  def load_balancer_health_checks_members(persister_load_balancer_health_check, uid)
    collector.health_check_members(uid).each do |member|
      persister_health_check_member = persister.load_balancer_health_check_members.find_or_build_by(
        :load_balancer_health_check => persister_load_balancer_health_check,
        :load_balancer_pool_member  => persister.load_balancer_pool_members.lazy_find(member['instance_id']),
      )
      persister_health_check_member.assign_attributes(
        :status        => member['state'],
        :status_reason => member['description']
      )
    end
  end

  def get_floating_ips
    process_inventory_collection(collector.floating_ips, :floating_ips) { |ip| parse_floating_ip(ip) }
  end

  def get_network_ports
    process_inventory_collection(collector.network_ports, :network_ports) do |n|
      get_public_ips(n)
      get_cloud_subnet_network_ports(n)

      parse_network_port(n)
    end
  end

  def get_public_ips(network_port)
    public_ips = []

    network_port['private_ip_addresses'].each do |private_address|
      if private_address['association'] &&
         !(public_ip = private_address.fetch_path('association', 'public_ip')).blank? &&
         private_address.fetch_path('association', 'allocation_id').blank?

        public_ips << {
          :network_port_id    => network_port['network_interface_id'],
          :private_ip_address => private_address['private_ip_address'],
          :public_ip_address  => public_ip
        }
      end
    end
    process_inventory_collection(public_ips, :floating_ips) { |public_ip| parse_public_ip(public_ip) }
  end

  def get_cloud_subnet_network_ports(network_port)
    process_inventory_collection(network_port['private_ip_addresses'], :cloud_subnet_network_ports) do |address|
      parse_cloud_subnet_network_port(network_port, address)
    end
  end

  def get_ec2_floating_ips_and_ports
    process_inventory_collection(collector.instances, :network_ports) do |instance|
      next unless instance['network_interfaces'].blank?

      get_ec2_cloud_subnet_network_port(instance)
      get_floating_ip_inferred_from_instance(instance)

      parse_network_port_inferred_from_instance(instance)
    end
  end

  def get_floating_ip_inferred_from_instance(instance)
    process_inventory_collection([instance], :floating_ips) { |i| parse_floating_ip_inferred_from_instance(i) }
  end

  def get_ec2_cloud_subnet_network_port(instance)
    # Create network_port placeholder for old EC2 instances, those do not have interface nor subnet nor VPC
    process_inventory_collection([instance], :cloud_subnet_network_ports) { |i| parse_ec2_cloud_subnet_network_port(i) }
  end

  def parse_floating_ip(ip)
    cloud_network_only = ip['domain']['vpc'] ? true : false
    address            = ip['public_ip']
    uid                = cloud_network_only ? ip['allocation_id'] : ip['public_ip']

    {
      :type                  => self.class.floating_ip_type.name,
      :ext_management_system => ems,
      :ems_ref               => uid,
      :address               => address,
      :fixed_ip_address      => ip['private_ip_address'],
      :cloud_network_only    => cloud_network_only,
      :network_port          => persister.network_ports.lazy_find(ip['network_interface_id']),
      :vm                    => persister.vms.lazy_find(ip['instance_id'])
    }
  end

  def parse_floating_ip_inferred_from_instance(instance)
    address = uid = instance['public_ip_address']
    return nil if uid.blank?

    {
      :type                  => self.class.floating_ip_type.name,
      :ext_management_system => ems,
      :ems_ref               => uid,
      :address               => address,
      :fixed_ip_address      => instance['private_ip_address'],
      :cloud_network_only    => false,
      :network_port          => persister.network_ports.lazy_find(instance['instance_id']),
      :vm                    => persister.vms.lazy_find(instance['instance_id'])
    }
  end

  def parse_public_ip(public_ip)
    address = uid = public_ip[:public_ip_address]

    {
      :type                  => self.class.floating_ip_type.name,
      :ext_management_system => ems,
      :ems_ref               => uid,
      :address               => address,
      :fixed_ip_address      => public_ip[:private_ip_address],
      :cloud_network_only    => true,
      :network_port          => persister.network_ports.lazy_find(public_ip[:network_port_id]),
      :vm                    => persister.network_ports.lazy_find(public_ip[:network_port_id], :key => :device)
    }
  end

  def parse_cloud_subnet_network_port(network_port, address)
    {
      :address      => address['private_ip_address'],
      :cloud_subnet => persister.cloud_subnets.lazy_find(network_port['subnet_id']),
      :network_port => persister.network_ports.lazy_find(network_port['network_interface_id'])
    }
  end

  def parse_ec2_cloud_subnet_network_port(instance)
    {
      :address      => instance['private_ip_address'],
      :cloud_subnet => nil,
      :network_port => persister.network_ports.lazy_find(instance['instance_id'])
    }
  end

  def parse_network_port(network_port)
    uid             = network_port['network_interface_id']
    security_groups = network_port['groups'].blank? ? [] : network_port['groups'].map do |x|
      persister.security_groups.lazy_find(x['group_id'])
    end

    {
      :type                  => self.class.network_port_type.name,
      :ext_management_system => ems,
      :name                  => uid,
      :ems_ref               => uid,
      :status                => network_port['status'],
      :mac_address           => network_port['mac_address'],
      :device_owner          => network_port.fetch_path('attachment', 'instance_owner_id'),
      :device_ref            => network_port.fetch_path('attachment', 'instance_id'),
      :device                => persister.vms.lazy_find(network_port.fetch_path('attachment', 'instance_id')),
      :security_groups       => security_groups,
    }
  end

  def parse_network_port_inferred_from_instance(instance)
    uid  = instance['instance_id']
    name = get_from_tags(instance, 'name')
    name ||= uid

    {
      :type                  => self.class.network_port_type.name,
      :ext_management_system => ems,
      :name                  => name,
      :ems_ref               => uid,
      :status                => nil,
      :mac_address           => nil,
      :device_owner          => nil,
      :device_ref            => nil,
      :device                => persister.vms.lazy_find(uid),
      :security_groups       => instance['security_groups'].to_a.collect do |sg|
        persister.security_groups.lazy_find(sg['group_id'])
      end.compact,
    }
  end

  # Overridden helper methods, we should put them in helper once we get rid of old refresh
  def get_from_tags(resource, item)
    (resource['tags'] || []).detect { |tag, _| tag['key'].downcase == item.to_s.downcase }.try(:[], 'value')
  end

  class << self
    def load_balancer_type
      ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer
    end

    def load_balancer_listener_type
      ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener
    end

    def load_balancer_health_check_type
      ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerHealthCheck
    end

    def load_balancer_pool_type
      ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPool
    end

    def load_balancer_pool_member_type
      ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPoolMember
    end

    def security_group_type
      ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup
    end

    def network_router_type
      ManageIQ::Providers::Amazon::NetworkManager::NetworkRouter
    end

    def cloud_network_type
      ManageIQ::Providers::Amazon::NetworkManager::CloudNetwork
    end

    def cloud_subnet_type
      ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet
    end

    def floating_ip_type
      ManageIQ::Providers::Amazon::NetworkManager::FloatingIp
    end

    def network_port_type
      ManageIQ::Providers::Amazon::NetworkManager::NetworkPort
    end
  end
end
