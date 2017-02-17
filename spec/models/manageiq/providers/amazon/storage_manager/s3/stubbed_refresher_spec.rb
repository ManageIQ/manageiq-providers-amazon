require_relative '../../aws_helper'
require_relative '../../aws_stubs'

describe ManageIQ::Providers::Amazon::StorageManager::S3::Refresher do
  include AwsStubs

  describe "refresh" do
    before do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @provider            = FactoryGirl.create(:provider_amazon, :zone => zone, :provider_regions => ['us-west-1'])
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)
    end

    # Test all kinds of refreshes
    [{:inventory_object_refresh => true},
     {:inventory_object_saving_strategy => :recursive, :inventory_object_refresh => true},
     {:inventory_object_refresh => false}].each do |settings|
      context "with settings #{settings}" do
        before :each do
          allow(Settings.ems_refresh).to receive(:s3).and_return(settings)
        end

        it "2 refreshes, first creates all entities, second updates all entitites" do
          2.times do
            # Make sure we don't do any delete&create instead of update
            assert_do_not_delete

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
            assert_do_not_delete

            refresh_spec
            @data_scaling += 1
          end
        end

        it "2 refreshes, first creates all entities, second deletes all entitites" do
          @data_scaling = 1
          2.times do
            refresh_spec
            @data_scaling -= 1
          end
        end
      end
    end
  end

  def refresh_spec
    @provider.reload

    with_aws_stubbed(stub_responses) do
      EmsRefresh.refresh(@provider.s3_storage_manager)
    end
    @provider.reload

    assert_table_counts
    assert_ems
  end

  def stub_responses
    {
      :s3 => {
        :list_buckets => {
          :buckets => mocked_s3_buckets
        }
      }
    }
  end

  def expected_table_counts
    {
      :auth_private_key                  => 0,
      :ext_management_system             => 4,
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
      :security_group                    => 0,
      :firewall_rule                     => 0,
      :network_port                      => 0,
      :cloud_network                     => 0,
      :floating_ip                       => 0,
      :network_router                    => 0,
      :cloud_subnet                      => 0,
      :custom_attribute                  => 0,
      :load_balancer                     => 0,
      :load_balancer_pool                => 0,
      :load_balancer_pool_member         => 0,
      :load_balancer_pool_member_pool    => 0,
      :load_balancer_listener            => 0,
      :load_balancer_listener_pool       => 0,
      :load_balancer_health_check        => 0,
      :load_balancer_health_check_member => 0,
      :cloud_object_store_containers     => test_counts[:s3_buckets_count]
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
      :cloud_object_store_containers     => CloudObjectStoreContainer.count
    }

    expect(actual).to eq expected_table_counts
  end

  def assert_ems
    ems = @provider.s3_storage_manager
    expect(ems).to have_attributes(:api_version => nil,
                                   :uid_ems     => nil)

    expect(ems.cloud_object_store_containers.size).to eql(expected_table_counts[:cloud_object_store_containers])
  end
end
