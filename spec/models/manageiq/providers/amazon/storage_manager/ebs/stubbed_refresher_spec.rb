require_relative '../../aws_helper'
require_relative '../../aws_stubs'

describe ManageIQ::Providers::Amazon::StorageManager::Ebs::Refresher do
  include AwsStubs

  describe "refresh" do
    before do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems                 = FactoryGirl.create(:ems_amazon, :zone => zone)
      @ems.update_authentication(:default => {:userid => "0123456789", :password => "ABCDEFGHIJKL345678efghijklmno"})
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)

      @disk = FactoryGirl.create(:disk, :controller_type => "amazon", :device_type => "disk", :device_name => "sda1", :location => "sda1")
      hardware = FactoryGirl.create(:hardware, :disks => [@disk])
      FactoryGirl.create(:vm_amazon, :ext_management_system => @ems, :ems_ref => "instance_0", :hardware => hardware)
    end

    # Test all kinds of refreshes, DTO refresh, DTO with batch saving and the original refresh
    [{:inventory_object_refresh => true},
     {:inventory_object_saving_strategy => :recursive, :inventory_object_refresh => true},
     {:inventory_object_refresh => false}].each do |settings|
      context "with settings #{settings}" do
        before :each do
          allow(Settings.ems_refresh).to receive(:ec2_ebs_storage).and_return(settings)
        end

        it "2 refreshes, first creates all entities, second updates all entitites" do
          2.times do
            # Make sure we don't do any delete&create instead of update
            assert_do_not_delete

            refresh_spec_full
          end
        end

        it "2 refreshes, first creates all entities, second updates exiting and deletes missing entitites" do
          @data_scaling = 2
          2.times do
            refresh_spec_full
            @data_scaling -= 1
          end
        end

        it "2 refreshes, first creates all entities, second updates existing and creates new entitites" do
          @data_scaling = 1
          2.times do
            # Make sure we don't do any delete&create instead of update
            assert_do_not_delete

            refresh_spec_full
            @data_scaling += 1
          end
        end

        it "2 refreshes, first creates all entities, second deletes all entitites" do
          @data_scaling = 1
          2.times do
            refresh_spec_counts
            @data_scaling -= 1
          end
        end
      end
    end
  end

  def refresh_spec_counts
    @ems.reload

    with_aws_stubbed(stub_responses) do
      EmsRefresh.refresh(@ems.ebs_storage_manager)
    end

    @ems.reload

    assert_table_counts
    assert_ems
  end

  def refresh_spec_full
    refresh_spec_counts

    assert_specific_snapshot
    assert_specific_volume
    assert_unencrypted_volume
  end

  def stub_responses
    {
      :ec2 => {
        :describe_volumes   => mocked_cloud_volumes,
        :describe_snapshots => mocked_cloud_volume_snapshots,
      }
    }
  end

  def expected_table_counts
    {
      :auth_private_key                  => 0,
      :ext_management_system             => expected_ext_management_systems_count,
      :flavor                            => 0,
      :availability_zone                 => 0,
      :vm_or_template                    => 1,
      :vm                                => 1,
      :miq_template                      => 0,
      :disk                              => 1,
      :guest_device                      => 0,
      :hardware                          => 1,
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
      :cloud_volume                      => test_counts[:cloud_volume_count],
      :cloud_volume_snapshot             => test_counts[:cloud_volume_snapshot_count],
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
      :cloud_volume                      => CloudVolume.count,
      :cloud_volume_snapshot             => CloudVolumeSnapshot.count,
    }

    expect(actual).to eq expected_table_counts
  end

  def assert_ems
    ems = @ems.ebs_storage_manager

    expect(ems).to have_attributes(:api_version => nil, # TODO: Should be 3.0
                                   :uid_ems     => nil)

    expect(ems.availability_zones.size).to eql(expected_table_counts[:availability_zone])
    expect(ems.cloud_volumes.size).to eql(expected_table_counts[:cloud_volume])
    expect(ems.cloud_volume_snapshots.size).to eql(expected_table_counts[:cloud_volume_snapshot])
  end

  def assert_specific_snapshot
    @snapshot = ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot.where(:ems_ref => "snapshot_id_0").first

    expect(@snapshot).not_to be_nil
    expect(@snapshot).to have_attributes(
      :ems_ref     => "snapshot_id_0",
      :name        => "snapshot_0",
      :description => "snapshot_desc_0",
      :status      => "completed",
      :size        => 1.gigabyte
    )

    expect(@snapshot.ext_management_system).to eq(@ems.ebs_storage_manager)
  end

  def assert_specific_volume
    @volume = ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume.where(:ems_ref => "volume_id_0").first

    expect(@volume).not_to be_nil
    expect(@volume).to have_attributes(
      :ems_ref     => "volume_id_0",
      :name        => "volume_0",
      :status      => "in-use",
      :volume_type => "standard",
      :size        => 1.gigabyte,
      :encrypted   => true,
      :iops        => 100
    )

    expect(@volume.ext_management_system).to eq(@ems.ebs_storage_manager)
    expect(@volume.base_snapshot).to eq(@snapshot)

    # EBS manager is updating attributes of the pre-existing disk so we need to reload the disk
    # before checking if the update was successful.
    @disk.reload
    expect(@disk.backing).to eq(@volume)
    expect(@disk.size).to eq(@volume.size)
  end

  def assert_unencrypted_volume
    @volume = ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume.where(:ems_ref => "volume_id_1").first

    expect(@volume).not_to be_nil
    expect(@volume).to have_attributes(
      :ems_ref     => "volume_id_1",
      :name        => "volume_1",
      :status      => "in-use",
      :volume_type => "standard",
      :size        => 1.gigabyte,
      :encrypted   => false,
      :iops        => nil
    )
  end
end
