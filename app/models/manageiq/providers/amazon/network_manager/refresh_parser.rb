# TODO: Separate collection from parsing (perhaps collecting in parallel a la RHEVM)

class ManageIQ::Providers::Amazon::NetworkManager::RefreshParser
  include ManageIQ::Providers::Amazon::RefreshHelperMethods

  def initialize(ems, options = nil)
    @ems        = ems
    @aws_ec2    = ems.connect
    @aws_elb    = ems.connect(:service => :ElasticLoadBalancing)
    @data       = {}
    @data_index = {}
    @options    = options || {}
  end

  def ems_inv_to_hashes
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

    $aws_log.info("#{log_header}...")
    # The order of the below methods does matter, because there are inner dependencies of the data!
    get_cloud_networks
    get_cloud_subnets
    get_security_groups
    get_network_ports
    get_load_balancers
    get_load_balancer_pools
    get_load_balancer_listeners
    get_load_balancer_health_checks
    get_ec2_floating_ips_and_ports
    get_floating_ips
    get_public_ips
    $aws_log.info("#{log_header}...Complete")

    @data
  end

  private

  def parent_manager_fetch_path(collection, ems_ref)
    @parent_manager_data ||= {}
    return @parent_manager_data.fetch_path(collection, ems_ref) if @parent_manager_data.has_key_path?(collection,
                                                                                                      ems_ref)

    @parent_manager_data.store_path(collection,
                                    ems_ref,
                                    @ems.public_send(collection).try(:where, :ems_ref => ems_ref).try(:first))
  end

  def security_groups
    @security_groups ||= @aws_ec2.security_groups
  end

  def load_balancers
    @load_balancers ||= @aws_elb.client.describe_load_balancers.load_balancer_descriptions
  end

  def network_ports
    @network_ports ||= @aws_ec2.client.describe_network_interfaces.network_interfaces
  end

  def get_cloud_networks
    vpcs = @aws_ec2.client.describe_vpcs[:vpcs]
    process_collection(vpcs, :cloud_networks) { |vpc| parse_cloud_network(vpc) }
  end

  def get_cloud_subnets
    cloud_subnets = @aws_ec2.client.describe_subnets[:subnets]
    process_collection(cloud_subnets, :cloud_subnets) { |s| parse_cloud_subnet(s) }
  end

  def get_security_groups
    process_collection(security_groups, :security_groups) { |sg| parse_security_group(sg) }
    get_firewall_rules
  end

  def get_firewall_rules
    security_groups.each do |sg|
      new_sg = @data_index.fetch_path(:security_groups, sg.group_id)
      new_sg[:firewall_rules] = get_inbound_firewall_rules(sg) + get_outbound_firewall_rules(sg)
    end
  end

  def get_inbound_firewall_rules(sg)
    sg.ip_permissions.collect { |perm| parse_firewall_rule(perm, "inbound") }.flatten
  end

  def get_outbound_firewall_rules(sg)
    sg.ip_permissions_egress.collect { |perm| parse_firewall_rule(perm, "outbound") }.flatten
  end

  def get_load_balancers
    process_collection(load_balancers, :load_balancers) { |lb| parse_load_balancer(lb) }
  end

  def get_load_balancer_pools
    process_collection(load_balancers, :load_balancer_pools) { |lb| parse_load_balancer_pool(lb) }
    get_load_balancer_pool_members
  end

  def get_load_balancer_pool_members
    @data[:load_balancer_pool_members] = []

    load_balancers.each do |lb|
      new_lb = @data_index.fetch_path(:load_balancer_pools, lb.load_balancer_name)
      load_balancer_pool_members = lb.instances.collect { |m| parse_load_balancer_pool_member(m) }
      load_balancer_pool_members.each do |member|
        # Store all unique pool members
        if @data_index.fetch_path(:load_balancer_pool_members, member[:ems_ref]).blank?
          @data_index.store_path(:load_balancer_pool_members, member[:ems_ref], member)
          @data[:load_balancer_pool_members] << member
        end
      end

      # fill M:N relation of pool to pool members
      new_lb[:load_balancer_pool_member_pools] = load_balancer_pool_members.collect do |x|
        {:load_balancer_pool_member => @data_index.fetch_path(:load_balancer_pool_members, x[:ems_ref])}
      end
    end
  end

  def get_load_balancer_listeners
    # Initialize the data, otherwise the saving code will not catch this when empty
    @data[:load_balancer_listeners] ||= []
    load_balancers.each do |lb|
      process_collection(lb.listener_descriptions, :load_balancer_listeners) do|listener|
        parse_load_balancer_listener(lb, listener)
      end
    end
  end

  def get_load_balancer_health_checks
    process_collection(load_balancers, :load_balancer_health_checks) { |lb| parse_load_balancer_health_check(lb) }
  end

  def get_floating_ips
    ips = @aws_ec2.client.describe_addresses.addresses
    # Take only floating ips that are not already in stored by ec2 flaoting_ips
    ips = ips.select do |floating_ip|
      floating_ip_id = floating_ip.allocation_id.blank? ? floating_ip.public_ip : floating_ip.allocation_id
      @data_index.fetch_path(:floating_ips, floating_ip_id).nil?
    end
    process_collection(ips, :floating_ips) { |ip| parse_floating_ip(ip) }
  end

  def get_public_ips
    public_ips = []
    network_ports.each do |network_port|
      network_port.private_ip_addresses.each do |private_address|
        if private_address.association && !(public_ip = private_address.association.public_ip).blank?
          allocation_id  = private_address.association.allocation_id
          floating_ip_id = allocation_id.blank? ? public_ip : allocation_id
          unless @data_index.fetch_path(:floating_ips, floating_ip_id)
            public_ips << {
              :network_port_id    => network_port.network_interface_id,
              :private_ip_address => private_address.private_ip_address,
              :public_ip_address  => public_ip
            }
          end
        end
      end
    end
    process_collection(public_ips, :floating_ips) { |public_ip| parse_public_ip(public_ip) }
  end

  def get_network_ports
    process_collection(network_ports, :network_ports) { |n| parse_network_port(n) }
  end

  def get_ec2_floating_ips_and_ports
    instances = @aws_ec2.instances.select { |instance| instance.network_interfaces.blank? }
    process_collection(instances, :network_ports) { |instance| parse_network_port_inferred_from_instance(instance) }
    process_collection(instances, :floating_ips) { |instance| parse_floating_ip_inferred_from_instance(instance) }
  end

  def parse_cloud_network(vpc)
    uid    = vpc.vpc_id

    name   = get_from_tags(vpc, :name)
    name ||= uid

    status  = (vpc.state == :available) ? "active" : "inactive"

    new_result = {
      :type                => self.class.cloud_network_type,
      :ems_ref             => uid,
      :name                => name,
      :cidr                => vpc.cidr_block,
      :status              => status,
      :enabled             => true,
      :orchestration_stack => parent_manager_fetch_path(:orchestration_stacks,
                                                        get_from_tags(vpc, "aws:cloudformation:stack-id")),
    }
    return uid, new_result
  end

  def parse_cloud_subnet(subnet)
    uid    = subnet.subnet_id

    name   = get_from_tags(subnet, :name)
    name ||= uid

    new_result = {
      :type              => self.class.cloud_subnet_type,
      :ems_ref           => uid,
      :name              => name,
      :cidr              => subnet.cidr_block,
      :status            => subnet.state.try(:to_s),
      :availability_zone => parent_manager_fetch_path(:availability_zones, subnet.availability_zone),
      :cloud_network     => @data_index.fetch_path(:cloud_networks, subnet.vpc_id),
    }

    return uid, new_result
  end

  def parse_security_group(sg)
    uid = sg.group_id

    new_result = {
      :type                => self.class.security_group_type,
      :ems_ref             => uid,
      :name                => sg.group_name,
      :description         => sg.description.try(:truncate, 255),
      :cloud_network       => @data_index.fetch_path(:cloud_networks, sg.vpc_id),
      :orchestration_stack => parent_manager_fetch_path(:orchestration_stacks,
                                                        get_from_tags(sg, "aws:cloudformation:stack-id")),
    }
    return uid, new_result
  end

  # TODO: Should ICMP protocol values have their own 2 columns, or
  #   should they override port and end_port like the Amazon API.
  def parse_firewall_rule(perm, direction)
    ret = []

    common = {
      :direction     => direction,
      :host_protocol => perm.ip_protocol.to_s.upcase,
      :port          => perm.from_port,
      :end_port      => perm.to_port,
    }

    perm.user_id_group_pairs.each do |g|
      new_result = common.dup
      new_result[:source_security_group] = @data_index.fetch_path(:security_groups, g.group_id)
      ret << new_result
    end
    perm.ip_ranges.each do |r|
      new_result = common.dup
      new_result[:source_ip_range] = r.cidr_ip
      ret << new_result
    end

    ret
  end

  def parse_load_balancer(lb)
    uid = lb.load_balancer_name

    new_result = {
      :type    => self.class.load_balancer_type,
      :ems_ref => uid,
      :name    => uid,
    }

    return uid, new_result
  end

  def parse_load_balancer_pool(lb)
    uid = name = lb.load_balancer_name

    new_result = {
      :type          => self.class.load_balancer_pool_type,
      :ems_ref       => uid,
      :name          => name,
    }

    return uid, new_result
  end

  def parse_load_balancer_pool_member(member)
    uid = member.instance_id

    {
      :type    => self.class.load_balancer_pool_member_type,
      :ems_ref => uid,
      # TODO(lsmola) AWS always associates to eth0 of the instances, we do not collect that info now, we need to do that
      # :network_port => get eth0 network_port
      :vm      => parent_manager_fetch_path(:vms, uid)
    }
  end

  def parse_load_balancer_listener(lb, listener_struct)
    listener = listener_struct.listener

    uid = "#{lb.load_balancer_name}__#{listener.protocol}__#{listener.load_balancer_port}__"\
          "#{listener.instance_protocol}__#{listener.instance_port}__#{listener.ssl_certificate_id}"

    new_result = {
      :type                         => self.class.load_balancer_listener_type,
      :ems_ref                      => uid,
      :load_balancer_protocol       => listener.protocol,
      :load_balancer_port_range     => (listener.load_balancer_port.to_i..listener.load_balancer_port.to_i),
      :instance_protocol            => listener.instance_protocol,
      :instance_port_range          => (listener.instance_port.to_i..listener.instance_port.to_i),
      :load_balancer                => @data_index.fetch_path(:load_balancers, lb.load_balancer_name),
      :load_balancer_listener_pools => [
        {:load_balancer_pool => @data_index.fetch_path(:load_balancer_pools, lb.load_balancer_name)}]
    }

    return uid, new_result
  end

  def parse_load_balancer_health_check(lb)
    uid = lb.load_balancer_name

    health_check_members = @aws_elb.client.describe_instance_health(:load_balancer_name => lb.load_balancer_name)
    health_check_members = health_check_members.instance_states.collect do |m|
      parse_load_balancer_health_check_member(m)
    end

    health_check = lb.health_check
    target_match = health_check.target.match(/^(\w+)\:(\d+)\/?(.*?)$/)
    protocol     = target_match[1]
    port         = target_match[2].to_i
    url_path     = target_match[3]

    matched_listener = @data.fetch_path(:load_balancer_listeners).detect do |listener|
      listener[:load_balancer][:ems_ref] == lb.load_balancer_name &&
        listener[:instance_port_range] == (port.to_i..port.to_i) &&
        listener[:instance_protocol] == protocol
    end

    new_result = {
      :type                               => self.class.load_balancer_health_check_type,
      :ems_ref                            => uid,
      :protocol                           => protocol,
      :port                               => port,
      :url_path                           => url_path,
      :interval                           => health_check.interval,
      :timeout                            => health_check.timeout,
      :unhealthy_threshold                => health_check.unhealthy_threshold,
      :healthy_threshold                  => health_check.healthy_threshold,
      :load_balancer                      => @data_index.fetch_path(:load_balancers, lb.load_balancer_name),
      :load_balancer_listener             => matched_listener,
      :load_balancer_health_check_members => health_check_members
    }

    return uid, new_result
  end

  def parse_load_balancer_health_check_member(member)
    {
      :load_balancer_pool_member => @data_index.fetch_path(:load_balancer_pool_members, member.instance_id),
      :status                    => member.state,
      :status_reason             => member.description
    }
  end

  def parse_floating_ip(ip)
    cloud_network_only = ip.domain == "vpc" ? true : false
    address            = ip.public_ip
    uid                = cloud_network_only ? ip.allocation_id : ip.public_ip

    new_result = {
      :type               => self.class.floating_ip_type,
      :ems_ref            => uid,
      :address            => address,
      :fixed_ip_address   => ip.private_ip_address,
      :cloud_network_only => cloud_network_only,
      :network_port       => @data_index.fetch_path(:network_ports, ip.network_interface_id),
      :vm                 => parent_manager_fetch_path(:vms, ip.instance_id)
    }

    return uid, new_result
  end

  def parse_floating_ip_inferred_from_instance(instance)
    address = uid = instance.public_ip_address

    new_result = {
      :type               => self.class.floating_ip_type,
      :ems_ref            => uid,
      :address            => address,
      :fixed_ip_address   => instance.private_ip_address,
      :cloud_network_only => false,
      :network_port       => @data_index.fetch_path(:network_ports, instance.id),
      :vm                 => parent_manager_fetch_path(:vms, instance.id)
    }

    return uid, new_result
  end

  def parse_public_ip(public_ip)
    address = uid = public_ip[:public_ip_address]
    new_result = {
      :type               => self.class.floating_ip_type,
      :ems_ref            => uid,
      :address            => address,
      :fixed_ip_address   => public_ip[:private_ip_address],
      :cloud_network_only => true,
      :network_port       => @data_index.fetch_path(:network_ports, public_ip[:network_port_id]),
      :vm                 => @data_index.fetch_path(:network_ports, public_ip[:network_port_id], :device)
    }

    return uid, new_result
  end

  def parse_cloud_subnet_network_port(cloud_subnet_network_port, subnet_id)
    {
      :address      => cloud_subnet_network_port.private_ip_address,
      :cloud_subnet => @data_index.fetch_path(:cloud_subnets, subnet_id)
    }
  end

  def parse_network_port(network_port)
    uid                        = network_port.network_interface_id
    cloud_subnet_network_ports = network_port.private_ip_addresses.map do |x|
      parse_cloud_subnet_network_port(x, network_port.subnet_id)
    end
    device                     = parent_manager_fetch_path(:vms, network_port.try(:attachment).try(:instance_id))
    security_groups            = network_port.groups.blank? ? [] : network_port.groups.map do |x|
      @data_index.fetch_path(:security_groups, x.group_id)
    end

    new_result = {
      :type                       => self.class.network_port_type,
      :name                       => uid,
      :ems_ref                    => uid,
      :status                     => network_port.status,
      :mac_address                => network_port.mac_address,
      :device_owner               => network_port.try(:attachment).try(:instance_owner_id),
      :device_ref                 => network_port.try(:attachment).try(:instance_id),
      :device                     => device,
      :cloud_subnet_network_ports => cloud_subnet_network_ports,
      :security_groups            => security_groups,
    }
    return uid, new_result
  end

  def parse_network_port_inferred_from_instance(instance)
    # Create network_port placeholder for old EC2 instances, those do not have interface nor subnet nor VPC
    cloud_subnet_network_ports = [parse_cloud_subnet_network_port(instance, nil)]

    uid    = instance.id
    name   = get_from_tags(instance, :name)
    name ||= uid

    device = parent_manager_fetch_path(:vms, uid)

    new_result = {
      :type                       => self.class.network_port_type,
      :name                       => name,
      :ems_ref                    => uid,
      :status                     => nil,
      :mac_address                => nil,
      :device_owner               => nil,
      :device_ref                 => nil,
      :device                     => device,
      :cloud_subnet_network_ports => cloud_subnet_network_ports,
      :security_groups            => instance.security_groups.to_a.collect do |sg|
        @data_index.fetch_path(:security_groups, sg.group_id)
      end.compact,
    }
    return uid, new_result
  end

  class << self
    def load_balancer_type
      ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer.name
    end

    def load_balancer_listener_type
      ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener.name
    end

    def load_balancer_health_check_type
      ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerHealthCheck.name
    end

    def load_balancer_pool_type
      ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPool.name
    end

    def load_balancer_pool_member_type
      ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPoolMember.name
    end

    def security_group_type
      ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup.name
    end

    def network_router_type
      ManageIQ::Providers::Amazon::NetworkManager::NetworkRouter.name
    end

    def cloud_network_type
      ManageIQ::Providers::Amazon::NetworkManager::CloudNetwork.name
    end

    def cloud_subnet_type
      ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet.name
    end

    def floating_ip_type
      ManageIQ::Providers::Amazon::NetworkManager::FloatingIp.name
    end

    def network_port_type
      ManageIQ::Providers::Amazon::NetworkManager::NetworkPort.name
    end
  end
end
