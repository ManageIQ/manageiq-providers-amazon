require_relative '../../aws_helper'
require_relative '../../aws_stubs'
require_relative '../../aws_refresher_spec_common'

describe ManageIQ::Providers::Amazon::StorageManager::S3::Refresher do
  include AwsRefresherSpecCommon
  include AwsStubs

  before do
    stub_settings_merge(:prototype => {:amazon => {:s3 => true }})

    skip("AWS S3 is disabled") unless ::Settings.prototype.amazon.s3
    EvmSpecHelper.local_miq_server(:zone => Zone.seed)
  end

  let :ems do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    ems = FactoryGirl.create(:ems_amazon, :zone => zone)
    ems.update_authentication(:default => {:userid => "0123456789", :password => "ABCDEFGHIJKL345678efghijklmno"})
    ems
  end

  describe "refresh" do
    (AwsRefresherSpecCommon::ALL_GRAPH_REFRESH_SETTINGS + AwsRefresherSpecCommon::ALL_OLD_REFRESH_SETTINGS
    ).each do |settings|
      context "with settings #{settings}" do
        before :each do
          stub_refresh_settings(settings)
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

        it "handles gracefully errors in bucket's object listing" do
          ems.reload

          with_aws_stubbed(stub_object_listing_exception) do
            EmsRefresh.refresh(ems.s3_storage_manager)
          end
          ems.reload

          expect(CloudObjectStoreObject.count).to eq 0
        end
      end
    end
  end

  describe "destructive operations (bucket)" do
    before do
      ems.cloud_object_store_containers << FactoryGirl.create_list(
        :aws_bucket_with_objects,
        5,
        :ext_management_system => ems.s3_storage_manager
      )
    end

    let :bucket do
      ems.cloud_object_store_containers.first
    end

    it "connect connects to :S3 service" do
      conn = ems.s3_storage_manager.connect

      expect(conn).to_not be_nil
      expect(conn.class).to eq(Aws::S3::Resource)
    end

    it "bucket's provider_object is of expected type" do
      with_aws_stubbed(stub_responses) do
        provider_obj = bucket.provider_object

        expect(provider_obj).to_not be_nil
        expect(provider_obj.class).to eq(Aws::S3::Bucket)
      end
    end

    it "delete_cloud_object_store_container triggers remote action" do
      expect(bucket).to receive(:with_provider_object)

      bucket.delete_cloud_object_store_container
    end

    it "remove bucket (trigger)" do
      options = {:ids => [bucket.id], :task => "delete_cloud_object_store_container", :userid => "admin"}

      expect { CloudObjectStoreContainer.process_tasks(options) }.to change { MiqQueue.count }.by(1)
    end

    it "remove bucket (process)" do
      with_aws_stubbed(stub_responses) do
        # should not remove from MIQ database, we rather rely on refresh
        expect { bucket.delete_cloud_object_store_container }.to change { ems.cloud_object_store_containers.count }.by(0)
      end
    end

    it "bucket type" do
      expect(bucket.class).to eq(ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreContainer)

      c = CloudObjectStoreContainer.find(bucket.id)

      expect(c.class).to eq(ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreContainer)
    end

    it "bucket with s3 should support delete" do
      with_aws_stubbed(stub_responses) do
        expect(bucket.supports?(:delete)).to be_truthy
      end
    end

    it "bucket without s3 should not support delete" do
      bucket.ext_management_system = nil
      with_aws_stubbed(stub_responses) do
        expect(bucket.supports?(:delete)).to be_falsey
      end
    end

    it "clear bucket (trigger)" do
      options = {:ids => [bucket.id], :task => "cloud_object_store_container_clear", :userid => "admin"}

      expect { CloudObjectStoreContainer.process_tasks(options) }.to change { MiqQueue.count }.by(1)
    end

    it "clear bucket (process)" do
      with_aws_stubbed(stub_responses) do
        # should not remove from MIQ database, we rather rely on refresh
        expect { bucket.raw_cloud_object_store_container_clear }.to change { ems.cloud_object_store_objects.count }.by(0)
      end
    end

    it "bucket with s3 should support clear" do
      with_aws_stubbed(stub_responses) do
        expect(bucket.supports?(:cloud_object_store_container_clear)).to be_truthy
      end
    end

    it "bucket without s3 should not support clear" do
      bucket.ext_management_system = nil
      with_aws_stubbed(stub_responses) do
        expect(bucket.supports?(:cloud_object_store_container_clear)).to be_falsey
      end
    end

    it "bucket without objects should not support clear" do
      bucket.cloud_object_store_objects = []

      expect(bucket.cloud_object_store_objects.count).to eq(0)

      with_aws_stubbed(stub_responses) do
        expect(bucket.supports?(:cloud_object_store_container_clear)).to be_falsey
      end
    end
  end

  describe "destructive operations (objects)" do
    before do
      ems.cloud_object_store_containers << FactoryGirl.create_list(
        :aws_bucket_with_objects,
        5,
        :ext_management_system => ems.s3_storage_manager
      )
    end

    let :bucket do
      ems.cloud_object_store_containers.first
    end

    let :object do
      bucket.cloud_object_store_objects.first
    end

    it "objects's provider_object is of expected type" do
      with_aws_stubbed(stub_responses) do
        provider_obj = object.provider_object

        expect(provider_obj).to_not be_nil
        expect(provider_obj.class).to eq(Aws::S3::Object)
      end
    end

    it "object delete triggers remote deletion" do
      expect(object).to receive(:with_provider_object)

      with_aws_stubbed(stub_responses) do
        object.delete_cloud_object_store_object
      end
    end

    it "remove object (trigger)" do
      options = {:ids => [object.id], :task => "delete_cloud_object_store_object", :userid => "admin"}

      expect { CloudObjectStoreObject.process_tasks(options) }.to change { MiqQueue.count }.by(1)
    end

    it "remove object (process)" do
      with_aws_stubbed(stub_responses) do
        # should not remove from MIQ database, we rather rely on refresh
        expect { object.delete_cloud_object_store_object }.to change { ems.cloud_object_store_objects.count }.by(0)
      end
    end

    it "object type" do
      expect(object.class).to eq(ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreObject)

      o = CloudObjectStoreObject.find(object.id)

      expect(o.class).to eq(ManageIQ::Providers::Amazon::StorageManager::S3::CloudObjectStoreObject)
    end

    it "object with s3 and bucket should support delete" do
      with_aws_stubbed(stub_responses) do
        expect(object.supports?(:delete)).to be_truthy
      end
    end

    it "object without s3 should not support delete" do
      object.ext_management_system = nil
      with_aws_stubbed(stub_responses) do
        expect(object.supports?(:delete)).to be_falsey
      end
    end

    it "object without bucket should not support delete" do
      object.cloud_object_store_container = nil
      with_aws_stubbed(stub_responses) do
        expect(object.supports?(:delete)).to be_falsey
      end
    end

    describe "delete folder" do
      before do
        allow(object.cloud_object_store_container).to receive(:provider_object)
          .and_return(provider_object_for_container)
      end

      let :provider_object_for_container do
        container = double("provider_object_for_container")
        allow(container).to receive(:objects).and_return(objects_batch)
        allow(container).to receive(:object).and_return(single_object)
        container
      end

      let :objects_batch do
        objects_batch = double("objects_batch")
        allow(objects_batch).to receive(:batch_delete!)
        objects_batch
      end

      let :single_object do
        single_object = double("single_object")
        allow(single_object).to receive(:delete)
        single_object
      end

      it "delete folder #1" do
        object.key = "myfolder/"
        expect(objects_batch).to receive(:batch_delete!)
        expect(single_object).not_to receive(:delete)

        with_aws_stubbed(stub_responses) do
          object.delete_cloud_object_store_object
        end
      end

      it "delete folder #2" do
        object.key = "myfolder/subfolder/"
        expect(objects_batch).to receive(:batch_delete!)
        expect(single_object).not_to receive(:delete)

        with_aws_stubbed(stub_responses) do
          object.delete_cloud_object_store_object
        end
      end

      it "delete regular object" do
        object.key = "file.txt"
        expect(objects_batch).not_to receive(:batch_delete!)
        expect(single_object).to receive(:delete)

        with_aws_stubbed(stub_responses) do
          object.delete_cloud_object_store_object
        end
      end
    end
  end

  def refresh_spec
    ems.reload

    with_aws_stubbed(stub_responses) do
      EmsRefresh.refresh(ems.s3_storage_manager)
    end
    ems.reload

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

  def stub_object_listing_exception
    {
      :s3 => {
        :list_buckets        => {
          :buckets => mocked_s3_buckets
        },
        :get_bucket_location => {
          :location_constraint => mocked_regions[:regions][0][:region_name]
        },
        :list_objects_v2     => Timeout::Error
      }
    }
  end

  def expected_table_counts
    {
      :auth_private_key                  => 0,
      :ext_management_system             => expected_ext_management_systems_count,
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
    ems_s3 = ems.s3_storage_manager
    expect(ems_s3).to have_attributes(:api_version => nil,
                                      :uid_ems     => nil)

    expect(ems_s3.cloud_object_store_containers.size).to eql(expected_table_counts[:cloud_object_store_containers])
  end
end
