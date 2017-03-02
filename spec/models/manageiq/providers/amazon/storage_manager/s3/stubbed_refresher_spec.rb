require_relative '../../aws_helper'
require_relative '../../aws_stubs'

describe ManageIQ::Providers::Amazon::StorageManager::S3::Refresher do
  include AwsStubs

  describe "refresh" do
    before do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems                 = FactoryGirl.create(:ems_amazon, :zone => zone)
      @ems.update_authentication(:default => {:userid => "0123456789", :password => "ABCDEFGHIJKL345678efghijklmno"})
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

  describe "decouple cloud manager from S3 manager" do
    before do
      @userid = 'userid_123456'
      @password = 'pass_654321'
      @userid2 = "#{@userid}_2"
      @password2 = "#{@password}_2"
      @userid3 = "#{@userid}_3"
      @password3 = "#{@password}_3"
    end

    it "cloud manager without authentication and then add and update it" do
      _, _, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_amazon, :zone => zone)

      expect(@ems.s3_storage_manager).not_to be_nil

      # create authentication
      @ems.update_authentication(:default => {:userid => @userid, :password => @password})

      expect(@ems.default_authentication.userid).to eq(@userid)
      expect(@ems.s3_storage_manager.default_authentication).not_to be_nil
      expect(@ems.s3_storage_manager.default_authentication.userid).to eq(@userid)

      # update authentication
      @ems.update_authentication(:default => {:userid => @userid2, :password => @password2})

      expect(@ems.default_authentication.userid).to eq(@userid2)
      expect(@ems.s3_storage_manager.default_authentication.userid).to eq(@userid2)
    end

    it "update any cloud manager authentication" do
      @ems1 = create_cloud_manager_with_auth(@userid, @password, @hostname, "us-west-1")
      @ems2 = create_cloud_manager_with_auth(@userid, @password, @hostname, "us-west-2")

      # update authentication of the first one
      @ems1.update_authentication(:default => {:userid => @userid2, :password => @password2})

      expect(@ems1.default_authentication.userid).to eq(@userid2)
      expect(@ems2.default_authentication.userid).to eq(@userid) # at the moment this one should not be updated
      expect(@ems1.s3_storage_manager.default_authentication.userid).to eq(@userid2)
      expect(@ems1.s3_storage_manager.default_authentication.password).to eq(@password2)

      # update authentication of the second one
      @ems2.update_authentication(:default => {:userid => @userid3, :password => @password3})

      expect(@ems2.default_authentication.userid).to eq(@userid3)
      expect(@ems2.s3_storage_manager.default_authentication.userid).to eq(@userid3)
      expect(@ems2.s3_storage_manager.default_authentication.password).to eq(@password3)
    end

    it "creating cloud provider creates standalone S3 as well" do
      @ems = create_cloud_manager_with_auth(@userid, @password, @hostname, "us-west-1")

      expect(@ems.s3_storage_manager).not_to be_nil
      expect(Authentication.count).to eq(2) # cloud manager + S3 manager
      expect(Endpoint.count).to eq(2)

      expect(@ems.default_authentication.userid).to eq(@ems.s3_storage_manager.default_authentication.userid)
      expect(@ems.default_authentication.password).to eq(@ems.s3_storage_manager.default_authentication.password)
      expect(@ems.default_authentication.id).not_to eq(@ems.s3_storage_manager.default_authentication.id)

      expect(@ems.default_endpoint.hostname).to eq(@ems.s3_storage_manager.default_endpoint.hostname)
      expect(@ems.default_endpoint.id).not_to eq(@ems.s3_storage_manager.default_endpoint.id)
    end

    it "2 cloud providers, first creates S3, second uses it" do
      @ems1 = create_cloud_manager_with_auth(@userid, @password, @hostname, "us-west-1")

      expect(ExtManagementSystem.count).to eq 4 # cloud + network + ebs + s3
      @s3 = @ems1.s3_storage_manager

      @ems2 = create_cloud_manager_with_auth(@userid, @password, @hostname, "us-west-2")

      expect(ExtManagementSystem.count).to eq 7 # 4 + 3
      expect(@ems2.s3_storage_manager).to eq @s3
    end

    it "3 cloud providers, but only two share S3 manager" do
      @ems1 = create_cloud_manager_with_auth(@userid, @password, @hostname, "us-west-1")
      @ems2 = create_cloud_manager_with_auth(@userid, @password, @hostname, "us-west-2")
      @ems3 = create_cloud_manager_with_auth("other_" + @userid, @password, @hostname, "us-west-1")

      expect(ExtManagementSystem.count).to eq 11 # 4 + 3 + 4
      expect(@ems1.s3_storage_manager).to eq @ems2.s3_storage_manager
      expect(@ems1.s3_storage_manager).not_to eq @ems3.s3_storage_manager
      expect(@ems2.s3_storage_manager).not_to eq @ems3.s3_storage_manager
    end

    it "delete S3 manager together with last cloud manager" do
      @ems1 = create_cloud_manager_with_auth(@userid, @password, @hostname, "us-west-1")
      @ems2 = create_cloud_manager_with_auth(@userid, @password, @hostname, "us-west-2")

      expect(ManageIQ::Providers::Amazon::StorageManager::S3.count).to eq(1)

      # delete first cloud manager; S3 should remain
      @ems1.destroy
      expect(ManageIQ::Providers::Amazon::StorageManager::S3.count).to eq(1)

      @ems2.destroy
      expect(ManageIQ::Providers::Amazon::StorageManager::S3.count).to eq(0)
    end

    it "list of cloud manager's storage managers contain S3" do
      @ems = create_cloud_manager_with_auth(@userid, @password, @hostname, "us-west-1")

      expect(@ems.storage_managers.find { |m| m.type == ManageIQ::Providers::Amazon::StorageManager::S3.name }).to_not be_nil
    end
  end

  def refresh_spec
    @ems.reload

    with_aws_stubbed(stub_responses) do
      EmsRefresh.refresh(@ems.s3_storage_manager)
    end
    @ems.reload

    assert_table_counts
    assert_buckets_content
    assert_ems
  end

  def stub_responses
    {
      :s3 => {
        :list_buckets        => {
          :buckets => mocked_s3_buckets
        },
        :get_bucket_location => {
          :location_constraint => mocked_regions[:regions][0][:region_name]
        },
        :list_objects_v2     => {
          :contents                => mocked_s3_objects,
          :next_continuation_token => nil,
          :is_truncated            => false
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
      :cloud_object_store_containers     => test_counts[:s3_buckets_count],
      :cloud_object_store_objects        => test_counts[:s3_buckets_count] * test_counts[:s3_objects_per_bucket_count]
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
      :cloud_object_store_containers     => CloudObjectStoreContainer.count,
      :cloud_object_store_objects        => CloudObjectStoreObject.count
    }

    expect(actual).to eq expected_table_counts
  end

  def assert_buckets_content
    mocked_objects = mocked_s3_objects
    expected_hash = {
      :object_count   => mocked_objects.count,
      :content_length => mocked_objects.map { |object| object[:size] }.sum,
    }
    actual = {}
    expected_content = {}
    CloudObjectStoreContainer.all.each do |container|
      expected_content[container.ems_ref] = expected_hash
      actual[container.ems_ref] = {
        :object_count   => container.object_count,
        :content_length => container.bytes
      }
    end
    expect(actual).to eq expected_content
  end

  def assert_ems
    ems = @ems.s3_storage_manager
    expect(ems).to have_attributes(:api_version => nil,
                                   :uid_ems     => nil)

    expect(ems.cloud_object_store_containers.size).to eql(expected_table_counts[:cloud_object_store_containers])
  end

  # cloud manager with its authentication and endpoints defined on create
  def create_cloud_manager_with_auth(userid, password, hostname, provider_region)
    _, _, zone = EvmSpecHelper.create_guid_miq_server_zone
    ems = FactoryGirl.build(:ems_amazon, :zone => zone, :provider_region => provider_region)
    ems.add_connection_configuration_by_role(
      :endpoint       => {:role => "default", :hostname => hostname},
      :authentication => {:userid => userid, :password => password}
    )

    expect(ems.save).to be_truthy
    expect(ems.endpoints.count).to eq(1)
    expect(ems.authentications.count).to eq(1)

    ems
  end
end
