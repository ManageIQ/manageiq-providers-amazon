module AwsStubs
  def scaling_factor
    @data_scaling || try(:data_scaling) || 1
  end

  def test_counts
    {
      :load_balancer_count                             => scaling_factor * 20,
      :instance_vpc_count                              => scaling_factor * 20,
      :instance_ec2_count                              => scaling_factor * 20,
      :load_balancer_instances_count                   => scaling_factor * 10,
      :vpc_count                                       => scaling_factor * 20,
      :subnet_count                                    => scaling_factor * 20,
      :network_port_count                              => scaling_factor * 20,
      :floating_ip_count                               => scaling_factor * 20,
      :security_group_count                            => scaling_factor * 20,
      :inbound_firewall_rule_per_security_group_count  => scaling_factor * 5,
      :outbound_firewall_rule_per_security_group_count => scaling_factor * 5,
    }
  end

  def mocked_floating_ips
    floating_ips = []
    test_counts[:floating_ip_count].times do |i|
      floating_ips << {
        :instance_id   => "instance_#{i}",
        :allocation_id => "allocation_#{i}",
        :public_ip     => "54.#{(i / 255) == 0 ? 0 : i % (i / 255)}.#{i / 255}.#{i % 255}",
        :domain        => "vpc"
      }
    end
    {:addresses => floating_ips}
  end

  def mocked_network_ports
    ports = []
    test_counts[:network_port_count].times do |i|
      ports << {
        :vpc_id               => "vpc_#{i}",
        :subnet_id            => "subnet_#{i}",
        :network_interface_id => "network_interface_#{i}",
        :attachment           => {:instance_id => "instance_#{i}"},
        :private_ip_addresses => [
          {
            :private_ip_address => "10.#{(i / 255) == 0 ? 0 : i % (i / 255)}.#{i / 255}.#{i % 255}",
            :primary            => true,
            :association        => {
              :public_ip     => "58.#{(i / 255) == 0 ? 0 : i % (i / 255)}.#{i / 255}.#{i % 255}",
              :allocation_id => nil
            }
          }, {
            :private_ip_address => "11.#{(i / 255) == 0 ? 0 : i % (i / 255)}.#{i / 255}.#{i % 255}",
          }]
      }
    end

    {:network_interfaces => ports}
  end

  def mocked_security_groups
    mocked_security_groups = []

    test_counts[:security_group_count].times do |i|
      inbound_firewall_rules = []
      test_counts[:inbound_firewall_rule_per_security_group_count].times do |fi|
        inbound_firewall_rules << {
          :ip_protocol         => "TCP",
          :from_port           => 0,
          :to_port             => fi,
          :user_id_group_pairs => [
            {
              :vpc_id => "vpc_#{i}"
            }]
        }
      end

      outbound_firewall_rules = []
      test_counts[:outbound_firewall_rule_per_security_group_count].times do |fi|
        outbound_firewall_rules << {
          :ip_protocol => "TCP",
          :from_port   => 0,
          :to_port     => fi,
          :ip_ranges   => [
            {
              :cidr_ip => "0.0.0.0/0"
            }]
        }
      end

      mocked_security_groups << {
        :group_id              => "security_group_#{i}",
        :vpc_id                => "vpc_#{i}",
        :ip_permissions        => inbound_firewall_rules,
        :ip_permissions_egress => outbound_firewall_rules
      }
    end
    {:security_groups => mocked_security_groups}
  end

  def mocked_instances
    instances = []
    test_counts[:instance_vpc_count].times do |i|
      instances << {
        :instance_id        => "instance_#{i}",
        :network_interfaces => [
          {
            :network_interface_id => "interface_#{i}"
          }]
      }
    end

    test_counts[:instance_ec2_count].times.each do |i|
      instances << {
        :instance_id => "instance_ec2#{i}"
      }
    end

    {:reservations => [{:instances => instances}]}
  end

  def mocked_vpcs
    mocked_vpcs = []
    test_counts[:vpc_count].times do |i|
      mocked_vpcs << {
        :vpc_id => "vpc_#{i}"
      }
    end

    {:vpcs => mocked_vpcs}
  end

  def mocked_subnets
    mocked_subnets = []
    test_counts[:subnet_count].times do |i|
      mocked_subnets << {
        :vpc_id    => "vpc_#{i}",
        :subnet_id => "subnet_#{i}"
      }
    end

    {:subnets => mocked_subnets}
  end

  def mocked_load_balancers
    mocked_lbs = []
    expected_table_counts[:load_balancer].times do |i|
      instances = []
      test_counts[:load_balancer_instances_count].times do |ins|
        instance             = OpenStruct.new
        instance.instance_id = "instance_#{ins}"
        instances << instance.to_h
      end

      health_check                     = OpenStruct.new
      health_check.target              = "TCP:22"
      health_check.interval            = 30
      health_check.timeout             = 5
      health_check.unhealthy_threshold = 2
      health_check.healthy_threshold   = 10

      listener                    = OpenStruct.new
      listener.protocol           = "TCP"
      listener.load_balancer_port = 2222
      listener.instance_protocol  = "TCP"
      listener.instance_port      = 22
      listener.ssl_certificate_id = nil

      listener_desc              = OpenStruct.new
      listener_desc.listener     = listener.to_h
      listener_desc.policy_names = []

      source_security_group             = OpenStruct.new
      source_security_group.owner_alias = "200278856672"
      source_security_group.group_name  = "quick-create-1"

      lb                               = OpenStruct.new
      lb.load_balancer_name            = "EmSRefreshSpecVPC#{i}"
      lb.dns_name                      = "EmSRefreshSpecVPCELB#{i}-1206960929.us-east-1.elb.amazonaws.com"
      lb.canonical_hosted_zone_name    = "EmSRefreshSpecVPCELB#{i}-1206960929.us-east-1.elb.amazonaws.com"
      lb.canonical_hosted_zone_name_id = "Z35SXDOTRQ7X7#{i}"
      lb.listener_descriptions         = [listener_desc.to_h]
      lb.policies                      = {}
      lb.backend_server_descriptions   = []
      lb.availability_zones            = ["us-east-1d", "us-east-1e"]
      lb.subnets                       = ["subnet_1", "subnet_2"]
      lb.vpc_id                        = "vpc-ff49ff91"
      lb.instances                     = instances
      lb.health_check                  = health_check.to_h
      lb.source_security_group         = source_security_group.to_h
      lb.security_groups               = ["sg-0d2cd677"]
      lb.created_time                  = Time.parse("2016-08-10 14:17:09 UTC")
      lb.scheme                        = "internet-facing"
      mocked_lbs << lb.to_h
    end
    mocked_lbs
  end

  def mocked_instance_health
    mocked_instance_healths = []
    expected_table_counts[:load_balancer_pool_member].times do |i|
      health             = OpenStruct.new
      health.instance_id = "instance_#{i}"
      health.state       = "OutOfService"
      health.reason_code = "Instance"
      health.description = "Instance has failed at least the UnhealthyThreshold number of health checks consecutively."
      mocked_instance_healths << health.to_h
    end
    mocked_instance_healths
  end
end
