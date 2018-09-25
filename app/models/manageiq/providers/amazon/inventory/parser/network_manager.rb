class ManageIQ::Providers::Amazon::Inventory::Parser::NetworkManager < ManageIQ::Providers::Amazon::Inventory::Parser
  def parse
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{collector.manager.name}] id: [#{collector.manager.id}]"

    $aws_log.info("#{log_header}...")
    # The order below matters
    build_and_index_network_routers

    # The order of the below methods doesn't matter since they refer to each other using only lazy links
    cloud_networks
    cloud_subnets
    security_groups
    network_ports
    load_balancers
    ec2_floating_ips_and_ports
    floating_ips
    $aws_log.info("#{log_header}...Complete")
  end

  private

  def build_and_index_network_routers
    # We need to pre-calculate NetworkRouter relations, because AWS Subnet api doesn't offer us a foreign_key for each
    # router
    @indexed_routers = {:cloud_subnets_ems_ref => {}, :cloud_networks_ems_ref => {}}

    collector.network_routers.each do |network_router|
      uid              = network_router['route_table_id']
      main_route_table = false
      network_router['associations'].each do |association|
        network_router_lazy = persister.network_routers.lazy_find(uid)
        if association['main']
          main_route_table                                                    = true
          @indexed_routers[:cloud_networks_ems_ref][network_router['vpc_id']] = network_router_lazy
        else
          @indexed_routers[:cloud_subnets_ems_ref][association['subnet_id']] = network_router_lazy
        end
      end

      persister.network_routers.find_or_build(uid).assign_attributes(
        :status           => network_router['routes'].all? { |x| x['state'] == 'active' } ? 'active' : 'inactive',
        :name             => get_from_tags(network_router, "Name") || uid,
        :extra_attributes => {
          :main_route_table => main_route_table,
          :routes           => network_router['routes'],
          :propagating_vgws => network_router['propagating_vgws']
        },
        # TODO(lsmola) model orchestration_stack_id relation for a NetworkRouter
        # :orchestration_stack => persister.orchestration_stacks.lazy_find(get_from_tags(network_router, "aws:cloudformation:stack-id")),
      )
    end
  end

  def cloud_networks
    collector.cloud_networks.each do |vpc|
      persister.cloud_networks.find_or_build(vpc['vpc_id']).assign_attributes(
        :name                => get_from_tags(vpc, 'name') || vpc['vpc_id'],
        :cidr                => vpc['cidr_block'],
        :status              => vpc['state'] == "available" ? "active" : "inactive",
        :enabled             => true,
        :orchestration_stack => persister.orchestration_stacks.lazy_find(
          get_from_tags(vpc, "aws:cloudformation:stack-id")
        ),
      )
    end
  end

  def cloud_subnets
    collector.cloud_subnets.each do |subnet|
      persister_cloud_subnet = persister.cloud_subnets.find_or_build(subnet['subnet_id']).assign_attributes(
        :name              => get_from_tags(subnet, 'name') || subnet['subnet_id'],
        :cidr              => subnet['cidr_block'],
        :status            => subnet['state'].try(:to_s),
        :availability_zone => persister.availability_zones.lazy_find(subnet['availability_zone']),
        :cloud_network     => persister.cloud_networks.lazy_find(subnet['vpc_id']),
      )

      network_router_lazy = @indexed_routers[:cloud_subnets_ems_ref][subnet['subnet_id']] || @indexed_routers[:cloud_networks_ems_ref][subnet['vpc_id']]
      persister_cloud_subnet.network_router = network_router_lazy if network_router_lazy
    end
  end

  def security_groups
    collector.security_groups.each do |sg|
      persister_security_group = persister.security_groups.find_or_build(sg['group_id']).assign_attributes(
        :name                => sg['group_name'].presence || sg['group_id'],
        :description         => sg['description'].try(:truncate, 255),
        :cloud_network       => persister.cloud_networks.lazy_find(sg['vpc_id']),
        :orchestration_stack => persister.orchestration_stacks.lazy_find(
          get_from_tags(sg, "aws:cloudformation:stack-id")
        ),
      )

      sg['ip_permissions'].each { |perm| firewall_rule(persister_security_group, perm, "inbound") }
      sg['ip_permissions_egress'].each { |perm| firewall_rule(persister_security_group, perm, "outbound") }
    end
  end

  # TODO: Should ICMP protocol values have their own 2 columns, or
  #   should they override port and end_port like the Amazon API.
  def firewall_rule(persister_security_group, perm, direction)
    common = {
      :direction             => direction,
      :host_protocol         => perm['ip_protocol'].to_s == "-1" ? _("All") : perm['ip_protocol'].to_s.upcase,
      :port                  => perm['from_port'],
      :end_port              => perm['to_port'],
      :resource              => persister_security_group,
      :source_security_group => nil,
      :source_ip_range       => nil,
    }

    (perm['user_id_group_pairs'] || []).each do |g|
      firewall_rule                         = common.dup
      firewall_rule[:source_security_group] = persister.security_groups.lazy_find(g['group_id'])
      persister.firewall_rules.build(firewall_rule)
    end

    (perm['ip_ranges'] || []).each do |r|
      firewall_rule                   = common.dup
      firewall_rule[:source_ip_range] = r['cidr_ip']
      persister.firewall_rules.build(firewall_rule)
    end

    (perm['ipv_6_ranges'] || []).each do |r|
      firewall_rule                   = common.dup
      firewall_rule[:source_ip_range] = r['cidr_ipv_6']
      persister.firewall_rules.build(firewall_rule)
    end
  end

  def load_balancers
    collector.load_balancers.each do |lb|
      uid = lb['load_balancer_name']

      persister_load_balancer = persister.load_balancers.find_or_build(uid).assign_attributes(
        :name => uid,
      )

      persister_load_balancer_pool = persister.load_balancer_pools.find_or_build(uid).assign_attributes(
        :name => uid,
      )

      load_balancer_pool_members(persister_load_balancer_pool, lb['instances'])
      load_balancer_listeners(persister_load_balancer, persister_load_balancer_pool, lb)
      load_balancer_health_checks(persister_load_balancer, uid, lb['health_check'])
      load_balancer_floating_ip_and_port(persister_load_balancer, uid, lb)
    end
  end

  def load_balancer_pool_members(persister_load_balancer_pool, members)
    members.each do |member|
      uid = member['instance_id']

      persister_load_balancer_pool_member = persister.load_balancer_pool_members.find_or_build(uid).assign_attributes(
        # TODO(lsmola) AWS always associates to eth0 of the instances, we do not collect that info now, we need to do that
        # :network_port => get eth0 network_port
        :vm => persister.vms.lazy_find(uid)
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

      persister_load_balancer_listener = persister.load_balancer_listeners.find_or_build(uid).assign_attributes(
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

    persister_load_balancer_health_check = persister.load_balancer_health_checks.find_or_build(uid).assign_attributes(
      :protocol            => protocol,
      :port                => port,
      :url_path            => url_path,
      :interval            => health_check['interval'],
      :timeout             => health_check['timeout'],
      :unhealthy_threshold => health_check['unhealthy_threshold'],
      :healthy_threshold   => health_check['healthy_threshold'],
      :load_balancer       => persister_load_balancer,
    )

    load_balancer_health_checks_members(persister_load_balancer_health_check, uid)
  end

  def load_balancer_floating_ip_and_port(persister_load_balancer, uid, lb)
    persister_network_port = persister.network_ports.find_or_build(uid).assign_attributes(
      :name            => uid,
      :status          => nil,
      :mac_address     => nil,
      :device_owner    => uid,
      :device_ref      => uid,
      :device          => persister_load_balancer,
      :security_groups => lb['security_groups'].to_a.collect do |security_group_id|
        persister.security_groups.lazy_find(security_group_id)
      end.compact,
    )

    lb['subnets'].each do |subnet_id|
      persister.cloud_subnet_network_ports.find_or_build_by(
        :address      => nil,
        :cloud_subnet => persister.cloud_subnets.lazy_find(subnet_id),
        :network_port => persister_network_port
      )
    end

    persister.floating_ips.find_or_build(uid).assign_attributes(
      :address            => lb['dns_name'],
      :fixed_ip_address   => nil,
      :cloud_network_only => lb['vpc_id'].present?,
      :network_port       => persister_network_port,
      :cloud_network      => lb['vpc_id'].present? ? persister.cloud_networks.lazy_find(lb['vpc_id']) : nil,
      :status             => nil,
      :vm                 => nil
    )
  end

  def load_balancer_health_checks_members(persister_load_balancer_health_check, uid)
    collector.health_check_members(uid).each do |member|
      persister.load_balancer_health_check_members.find_or_build_by(
        :load_balancer_health_check => persister_load_balancer_health_check,
        :load_balancer_pool_member  => persister.load_balancer_pool_members.lazy_find(member['instance_id']),
      ).assign_attributes(
        :status        => member['state'],
        :status_reason => member['description']
      )
    end
  end

  def floating_ips
    collector.floating_ips.each do |ip|
      cloud_network_only = ip['domain']['vpc'] ? true : false
      address            = ip['public_ip']
      uid                = cloud_network_only ? ip['allocation_id'] : ip['public_ip']

      # These are solved by the ec2_floating_ips_and_ports and they need to be solved there. Seems like there is a bug
      # that the private ip is not present in this list, but it's under ec2_floating_ips_and_ports ips, but only for
      # the non VPC instances.
      next if !cloud_network_only && ip['instance_id'] && persister.floating_ips.primary_index.find(uid)

      persister.floating_ips.find_or_build(uid).assign_attributes(
        :address            => address,
        :fixed_ip_address   => ip['private_ip_address'],
        :cloud_network_only => cloud_network_only,
        :network_port       => persister.network_ports.lazy_find(ip['network_interface_id']),
        :vm                 => persister.vms.lazy_find(ip['instance_id'])
      )
    end
  end

  def network_ports
    collector.network_ports.each do |network_port|
      uid             = network_port['network_interface_id']
      security_groups = network_port['groups'].blank? ? [] : network_port['groups'].map do |x|
        persister.security_groups.lazy_find(x['group_id'])
      end

      persister_network_port = persister.network_ports.find_or_build(uid).assign_attributes(
        :name            => uid,
        :status          => network_port['status'],
        :mac_address     => network_port['mac_address'],
        :device_owner    => network_port.fetch_path('attachment', 'instance_owner_id'),
        :device_ref      => network_port.fetch_path('attachment', 'instance_id'),
        :device          => persister.vms.lazy_find(network_port.fetch_path('attachment', 'instance_id')),
        :security_groups => security_groups,
      )

      network_port['private_ip_addresses'].each do |address|
        persister.cloud_subnet_network_ports.find_or_build_by(
          :address      => address['private_ip_address'],
          :cloud_subnet => persister.cloud_subnets.lazy_find(network_port['subnet_id']),
          :network_port => persister_network_port
        )
      end

      public_ips(network_port)
    end
  end

  def public_ips(network_port)
    network_port['private_ip_addresses'].each do |private_address|
      if private_address['association'] &&
         !(public_ip = private_address.fetch_path('association', 'public_ip')).blank? &&
         private_address.fetch_path('association', 'allocation_id').blank?

        persister.floating_ips.find_or_build(public_ip).assign_attributes(
          :address            => public_ip,
          :fixed_ip_address   => private_address['private_ip_address'],
          :cloud_network_only => true,
          :network_port       => persister.network_ports.lazy_find(network_port['network_interface_id']),
          :vm                 => persister.network_ports.lazy_find(network_port['network_interface_id'],
                                                                   :key => :device)
        )
      end
    end
  end

  def ec2_floating_ips_and_ports
    collector.instances.each do |instance|
      next unless instance['network_interfaces'].blank?

      persister_network_port = persister.network_ports.find_or_build(instance['instance_id']).assign_attributes(
        :name            => get_from_tags(instance, 'name') || instance['instance_id'],
        :status          => nil,
        :mac_address     => nil,
        :device_owner    => nil,
        :device_ref      => nil,
        :device          => persister.vms.lazy_find(instance['instance_id']),
        :security_groups => instance['security_groups'].to_a.collect do |sg|
          persister.security_groups.lazy_find(sg['group_id'])
        end.compact,
      )

      persister.cloud_subnet_network_ports.find_or_build_by(
        :address      => instance['private_ip_address'],
        :cloud_subnet => nil,
        :network_port => persister_network_port
      )

      floating_ip_inferred_from_instance(persister_network_port, instance)
    end
  end

  def floating_ip_inferred_from_instance(persister_network_port, instance)
    uid = instance['public_ip_address']
    return nil if uid.blank?

    persister.floating_ips.find_or_build(uid).assign_attributes(
      :address            => uid,
      :fixed_ip_address   => instance['private_ip_address'],
      :cloud_network_only => false,
      :network_port       => persister_network_port,
      :vm                 => persister_network_port.device
    )
  end
end
