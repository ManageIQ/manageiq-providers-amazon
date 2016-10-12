require_relative '../aws_helper'
require_relative '../aws_stubs'

describe ManageIQ::Providers::Amazon::NetworkManager::Refresher do
  include AwsStubs

  describe "refresh" do
    before do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems                 = FactoryGirl.create(:ems_amazon, :zone => zone)
      @ems.update_authentication(:default => {:userid => "0123456789", :password => "ABCDEFGHIJKL345678efghijklmno"})
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)

      allow(Settings.ems_refresh).to receive(:ec2_network).and_return({:dto_batch_saving => true,
                                                                       :dto_refresh      => true})
    end
    [{:dto_batch_saving => true, :dto_refresh => true},
     {:dto_batch_saving => false, :dto_refresh => true},
     {:dto_batch_saving => false, :dto_refresh => false}
    ].each do |settings|
      context "with settings #{settings}" do
        it "2 refreshes, first creates all entities, second updates all entitites" do
          2.times do
            # Make sure we don't do any delete&create instead of update
            allow_any_instance_of(ApplicationRecord).to(
              receive(:delete).and_raise("Not allowed delete operation detected. The probable cause is a wrong manager_ref"\
                                         "causing create&delete instead of update"))
            allow_any_instance_of(ActiveRecord::Associations::CollectionProxy).to(
              receive(:delete).and_raise("Not allowed delete operation detected. The probable cause is a wrong manager_ref"\
                                         "causing create&delete instead of update"))

            refresh_spec
          end
        end

        it "2 refreshes, first creates all entities, second updates exiting and deletes missing entitites" do
          @data_scaling = 2
          2.times do
            refresh_spec
            @data_scaling -= 1
          end
        end

        it "2 refreshes, first creates all entities, second updates existing and creates new entitites" do
          @data_scaling = 1
          2.times do
            # Make sure we don't do any delete&create instead of update
            allow_any_instance_of(ApplicationRecord).to(
              receive(:delete).and_raise("Not allowed delete operation detected. The probable cause is a wrong manager_ref"\
                                         "causing create&delete instead of update"))
            allow_any_instance_of(ActiveRecord::Associations::CollectionProxy).to(
              receive(:delete).and_raise("Not allowed delete operation detected. The probable cause is a wrong manager_ref"\
                                         "causing create&delete instead of update"))
            refresh_spec
            @data_scaling += 1
          end
        end
      end
    end
  end

  def refresh_spec
    @ems.reload


    with_aws_stubbed(stub_responses) do
      EmsRefresh.refresh(@ems.network_manager)
    end

    @ems.reload

    assert_table_counts
    assert_ems
  end

  def stub_responses
    {
      :elasticloadbalancing => {
        :describe_load_balancers  => {
          :load_balancer_descriptions => mocked_load_balancers
        },
        :describe_instance_health => {
          :instance_states => mocked_instance_health
        }
      },
      :ec2                  => {
        :describe_regions            => {
          :regions => [
            {:region_name => 'us-east-1'},
            {:region_name => 'us-west-1'},
          ]
        },
        :describe_instances          => mocked_instances,
        :describe_vpcs               => mocked_vpcs,
        :describe_subnets            => mocked_subnets,
        :describe_security_groups    => mocked_security_groups,
        :describe_network_interfaces => mocked_network_ports,
        :describe_addresses          => mocked_floating_ips
      }
    }
  end

  def expected_table_counts
    firewall_rule_count = test_counts[:security_group_count] *
      (test_counts[:outbound_firewall_rule_per_security_group_count] +
        test_counts[:outbound_firewall_rule_per_security_group_count])

    {
      :auth_private_key                  => 0,
      :ext_management_system             => 2,
      :flavor                            => 0,
      :availability_zone                 => 0,
      :vm_or_template                    => 0,
      :vm                                => 0,
      :miq_template                      => 0,
      :disk                              => 0,
      :guest_device                      => 0,
      :hardware                          => 0,
      :network                           => 0,
      :operating_system                  => 0,
      :snapshot                          => 0,
      :system_service                    => 0,
      # :relationship                      => 0,
      # :miq_queue                         => 2,
      # :orchestration_template            => 0,
      :orchestration_stack               => 0,
      :orchestration_stack_parameter     => 0,
      :orchestration_stack_output        => 0,
      :orchestration_stack_resource      => 0,
      :security_group                    => test_counts[:security_group_count],
      :firewall_rule                     => firewall_rule_count,
      :network_port                      => test_counts[:instance_ec2_count] + test_counts[:network_port_count],
      :cloud_network                     => test_counts[:vpc_count],
      :floating_ip                       => test_counts[:floating_ip_count] + test_counts[:network_port_count],
      :network_router                    => 0,
      # TODO(lsmola) the stubbed API can't do filter and we don't do unique check. Instead of test_counts[:subnet_count]
      # we have them multiplied by networks
      # :cloud_subnet                      => test_counts[:subnet_count] * test_counts[:vpc_count],
      :custom_attribute                  => 0,
      :load_balancer                     => test_counts[:load_balancer_count],
      :load_balancer_pool                => test_counts[:load_balancer_count],
      :load_balancer_pool_member         => test_counts[:load_balancer_instances_count],
      :load_balancer_pool_member_pool    => test_counts[:load_balancer_count] * test_counts[:load_balancer_instances_count],
      :load_balancer_listener            => test_counts[:load_balancer_count],
      :load_balancer_listener_pool       => test_counts[:load_balancer_count],
      :load_balancer_health_check        => test_counts[:load_balancer_count],
      :load_balancer_health_check_member => test_counts[:load_balancer_count] * test_counts[:load_balancer_instances_count],
    }
  end

  def assert_table_counts
    actual = {
      :auth_private_key                  => AuthPrivateKey.count,
      :ext_management_system             => ExtManagementSystem.count,
      :flavor                            => Flavor.count,
      :availability_zone                 => AvailabilityZone.count,
      :vm_or_template                    => VmOrTemplate.count,
      :vm                                => Vm.count,
      :miq_template                      => MiqTemplate.count,
      :disk                              => Disk.count,
      :guest_device                      => GuestDevice.count,
      :hardware                          => Hardware.count,
      :network                           => Network.count,
      :operating_system                  => OperatingSystem.count,
      :snapshot                          => Snapshot.count,
      :system_service                    => SystemService.count,
      # :relationship                      => Relationship.count,
      # :miq_queue                         => MiqQueue.count,
      # :orchestration_template            => OrchestrationTemplate.count,
      :orchestration_stack               => OrchestrationStack.count,
      :orchestration_stack_parameter     => OrchestrationStackParameter.count,
      :orchestration_stack_output        => OrchestrationStackOutput.count,
      :orchestration_stack_resource      => OrchestrationStackResource.count,
      :security_group                    => SecurityGroup.count,
      :firewall_rule                     => FirewallRule.count,
      :network_port                      => NetworkPort.count,
      :cloud_network                     => CloudNetwork.count,
      :floating_ip                       => FloatingIp.count,
      :network_router                    => NetworkRouter.count,
      # :cloud_subnet                      => CloudSubnet.count,
      :custom_attribute                  => CustomAttribute.count,
      :load_balancer                     => LoadBalancer.count,
      :load_balancer_pool                => LoadBalancerPool.count,
      :load_balancer_pool_member         => LoadBalancerPoolMember.count,
      :load_balancer_pool_member_pool    => LoadBalancerPoolMemberPool.count,
      :load_balancer_listener            => LoadBalancerListener.count,
      :load_balancer_listener_pool       => LoadBalancerListenerPool.count,
      :load_balancer_health_check        => LoadBalancerHealthCheck.count,
      :load_balancer_health_check_member => LoadBalancerHealthCheckMember.count,
    }

    expect(actual).to eq expected_table_counts
  end

  def assert_ems
    ems = @ems.network_manager

    expect(ems).to have_attributes(
                     :api_version => nil, # TODO: Should be 3.0
                     :uid_ems     => nil
                   )

    expect(ems.flavors.size).to eql(expected_table_counts[:flavor])
    expect(ems.availability_zones.size).to eql(expected_table_counts[:availability_zone])
    expect(ems.vms_and_templates.size).to eql(expected_table_counts[:vm_or_template])
    expect(ems.security_groups.size).to eql(expected_table_counts[:security_group])
    expect(ems.network_ports.size).to eql(expected_table_counts[:network_port])
    expect(ems.cloud_networks.size).to eql(expected_table_counts[:cloud_network])
    expect(ems.floating_ips.size).to eql(expected_table_counts[:floating_ip])
    expect(ems.network_routers.size).to eql(expected_table_counts[:network_router])
    # expect(ems.cloud_subnets.size).to eql(expected_table_counts[:cloud_subnet])
    expect(ems.miq_templates.size).to eq(expected_table_counts[:miq_template])

    expect(ems.orchestration_stacks.size).to eql(expected_table_counts[:orchestration_stack])

    expect(ems.load_balancers.size).to eql(expected_table_counts[:load_balancer])
  end
end
