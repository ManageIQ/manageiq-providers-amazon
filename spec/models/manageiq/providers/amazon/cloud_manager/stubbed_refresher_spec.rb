require_relative '../aws_helper'
require_relative '../aws_stubs'
require_relative '../aws_refresher_spec_common'

describe ManageIQ::Providers::Amazon::NetworkManager::Refresher do
  include AwsRefresherSpecCommon
  include AwsStubs

  describe "refresh" do
    before do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems                 = FactoryGirl.create(:ems_amazon, :zone => zone)
      @ems.update_authentication(:default => {:userid => "0123456789", :password => "ABCDEFGHIJKL345678efghijklmno"})
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)
    end

    (AwsRefresherSpecCommon::ALL_GRAPH_REFRESH_SETTINGS + AwsRefresherSpecCommon::ALL_OLD_REFRESH_SETTINGS
    ).each do |settings|
      context "with settings #{settings}" do
        before :each do
          stub_refresh_settings(
            settings.merge(
              :get_private_images => true,
              :get_shared_images  => false,
              :get_public_images  => false
            )
          )
          @inventory_object_settings = settings
        end

        it "2 refreshes, first creates all entities, second updates all entitites" do
          2.times do
            # Make sure we don't do any delete&create instead of update
            # TODO(lsmola) :inventory_object_refresh => false is doing some non allowed deletes, investigate
            assert_do_not_delete if @inventory_object_settings[:inventory_object_refresh]

            refresh_spec
          end
        end

        it "2 refreshes, first creates all entities, second updates exiting and deletes missing entitites" do
          @data_scaling         = 2
          @disconnect_inv_count = 0
          2.times do
            refresh_spec
            @data_scaling         -= 1
            @disconnect_inv_count += 1
          end
        end

        it "2 refreshes, first creates all entities, second updates existing and creates new entitites" do
          @data_scaling = 1
          2.times do
            # Make sure we don't do any delete&create instead of update
            # TODO(lsmola) :inventory_object_refresh => false is doing some non allowed deletes, investigate
            assert_do_not_delete if @inventory_object_settings[:inventory_object_refresh]

            refresh_spec
            @data_scaling += 1
          end
        end

        it "2 refreshes, first creates all entities, second deletes all entitites" do
          @data_scaling         = 1
          @disconnect_inv_count = 0

          2.times do
            refresh_spec
            @data_scaling         -= 1
            @disconnect_inv_count += 1
          end
        end

        it "2 refreshes, first creates all entities, second deletes all entitites from db" do
          # This spec verifies that all disconnected entities clean up correctly
          @data_scaling = 1

          2.times do
            refresh_spec do
              VmOrTemplate.all.map(&:destroy) if @data_scaling == 0
            end
            @data_scaling -= 1
          end
        end
      end
    end
  end

  def refresh_spec
    @ems.reload

    with_aws_stubbed(stub_responses) do
      EmsRefresh.refresh(@ems)
    end

    @ems.reload

    yield if block_given?

    assert_table_counts
    assert_ems
  end

  def stub_responses
    {
      :ec2            => {
        :describe_regions            => mocked_regions,
        :describe_availability_zones => mocked_availability_zones,
        :describe_instances          => mocked_instances,
        :describe_key_pairs          => mocked_key_pairs,
        :describe_images             => mocked_images,
      },
      :cloudformation => {
        :describe_stacks      => mocked_stacks,
        :list_stack_resources => mocked_stack_resources
      }
    }
  end

  def expected_table_counts(disconnect = nil)
    disconnect  ||= disconnect_inv_factor
    vm_count    = test_counts[:instance_vpc_count] + test_counts[:instance_ec2_count]
    image_count = test_counts[:image_count]

    # We have 3 custom_attributes per each vm + custom attributes of disconnected vm
    custom_attribute_count = (test_counts[:instance_vpc_count] * 3 + test_counts[:instance_ec2_count] * 3 +
      test_counts[:image_count] * 3)
    custom_attribute_count += disconnect * (test_counts(1)[:instance_vpc_count] * 3 +
      test_counts(1)[:instance_ec2_count] * 3 + test_counts(1)[:image_count] * 3)

    # Disconnect_inv count, when these objects are not found in the API, they are not deleted in DB, but just marked
    # as disconnected
    vm_count_plus_disconnect_inv    = vm_count + disconnect * (test_counts(1)[:instance_vpc_count] +
      test_counts(1)[:instance_ec2_count])
    image_count_plus_disconnect_inv = image_count + disconnect * test_counts(1)[:image_count]

    {
      :auth_private_key                  => test_counts[:key_pair_count],
      :ext_management_system             => expected_ext_management_systems_count,
      # TODO(lsmola) collect all flavors for original refresh
      :flavor                            => @inventory_object_settings[:inventory_object_refresh] ? 145 : 140,
      :availability_zone                 => 5,
      :vm_or_template                    => vm_count_plus_disconnect_inv + image_count_plus_disconnect_inv,
      :vm                                => vm_count_plus_disconnect_inv,
      :miq_template                      => image_count_plus_disconnect_inv,
      :disk                              => vm_count_plus_disconnect_inv,
      :guest_device                      => 0,
      :hardware                          => vm_count_plus_disconnect_inv + image_count_plus_disconnect_inv,
      :network                           => vm_count_plus_disconnect_inv * 2,
      :operating_system                  => vm_count_plus_disconnect_inv + image_count_plus_disconnect_inv,
      :snapshot                          => 0,
      :system_service                    => 0,
      :relationship                      => vm_count_plus_disconnect_inv + image_count_plus_disconnect_inv,
      # :miq_queue                         => 2,
      :orchestration_template            => 1,
      :orchestration_stack               => test_counts[:stack_count],
      :orchestration_stack_parameter     => test_counts[:stack_count] * test_counts[:stack_parameter_count],
      :orchestration_stack_output        => test_counts[:stack_count] * test_counts[:stack_output_count],
      :orchestration_stack_resource      => test_counts[:stack_count] * test_counts[:stack_resource_count],
      :security_group                    => 0,
      :firewall_rule                     => 0,
      :network_port                      => 0,
      :cloud_network                     => 0,
      :floating_ip                       => 0,
      :network_router                    => 0,
      :cloud_subnet                      => 0,
      :custom_attribute                  => custom_attribute_count,
      :load_balancer                     => 0,
      :load_balancer_pool                => 0,
      :load_balancer_pool_member         => 0,
      :load_balancer_pool_member_pool    => 0,
      :load_balancer_listener            => 0,
      :load_balancer_listener_pool       => 0,
      :load_balancer_health_check        => 0,
      :load_balancer_health_check_member => 0,
      :cloud_volume                      => 0,
      :cloud_volume_snapshot             => 0,
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
      :relationship                      => Relationship.count,
      # :miq_queue                         => MiqQueue.count,
      :orchestration_template            => OrchestrationTemplate.count,
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
      :cloud_subnet                      => CloudSubnet.count,
      :custom_attribute                  => CustomAttribute.count,
      :load_balancer                     => LoadBalancer.count,
      :load_balancer_pool                => LoadBalancerPool.count,
      :load_balancer_pool_member         => LoadBalancerPoolMember.count,
      :load_balancer_pool_member_pool    => LoadBalancerPoolMemberPool.count,
      :load_balancer_listener            => LoadBalancerListener.count,
      :load_balancer_listener_pool       => LoadBalancerListenerPool.count,
      :load_balancer_health_check        => LoadBalancerHealthCheck.count,
      :load_balancer_health_check_member => LoadBalancerHealthCheckMember.count,
      :cloud_volume                      => CloudVolume.count,
      :cloud_volume_snapshot             => CloudVolumeSnapshot.count,
    }

    expect(actual).to eq expected_table_counts
  end

  def assert_ems
    ems = @ems

    expect(ems).to have_attributes(
      :api_version => nil, # TODO: Should be 3.0
      :uid_ems     => nil
    )
    # The disconnected entities should not be associated to ems, so we get counts as expected_table_counts(0)
    expect(ems.flavors.size).to eql(expected_table_counts[:flavor])
    expect(ems.availability_zones.size).to eql(expected_table_counts[:availability_zone])
    expect(ems.vms_and_templates.size).to eql(expected_table_counts(0)[:vm_or_template])
    expect(ems.security_groups.size).to eql(expected_table_counts[:security_group])
    expect(ems.network_ports.size).to eql(expected_table_counts[:network_port])
    expect(ems.cloud_networks.size).to eql(expected_table_counts[:cloud_network])
    expect(ems.floating_ips.size).to eql(expected_table_counts[:floating_ip])
    expect(ems.network_routers.size).to eql(expected_table_counts[:network_router])
    expect(ems.cloud_subnets.size).to eql(expected_table_counts[:cloud_subnet])
    expect(ems.miq_templates.size).to eq(expected_table_counts(0)[:miq_template])

    expect(ems.orchestration_stacks.size).to eql(expected_table_counts[:orchestration_stack])
  end
end
