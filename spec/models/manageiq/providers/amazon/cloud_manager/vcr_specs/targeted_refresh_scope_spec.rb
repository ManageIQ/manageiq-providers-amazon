require_relative "../../aws_refresher_spec_common"
require_relative "../../aws_refresher_spec_counts"

describe ManageIQ::Providers::Amazon::CloudManager::Refresher do
  include AwsRefresherSpecCommon
  include AwsRefresherSpecCounts

  ######################################################################################################################
  # Spec scenarios for making sure targeted refresh stays in it's scope
  ######################################################################################################################
  #
  # We test every that every targeted refresh we do is staying in it's scope. The simplest test for this is that
  # after full refresh, targeted refresh should not change anything (just update existing items). So this verify the
  # targeted refresh is not deleting records that are out of its scope.

  before(:each) do
    @ems = FactoryGirl.create(:ems_amazon_with_vcr_authentication)
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ec2)
  end

  # Lets test only the fastest setting, since we test all settings elsewhere
  [
    :inventory_object_refresh => true,
    :inventory_collections    => {
      :saver_strategy => "batch",
      :use_ar_object  => false,
    },
  ].each do |settings|
    context "with settings #{settings}" do
      before(:each) do
        stub_refresh_settings(settings)
        create_tag_mapping
      end

      it "will refresh an EC2 classic VM powered on and LB full targeted refresh" do
        assert_targeted_refresh_scope do
          vm_target = InventoryRefresh::Target.new(:manager     => @ems,
                                                 :association => :vms,
                                                 :manager_ref => {:ems_ref => "i-680071e9"})
          lb_target = InventoryRefresh::Target.new(:manager     => @ems,
                                                 :association => :load_balancers,
                                                 :manager_ref => {:ems_ref => "EmsRefreshSpec-LoadBalancer"})

          2.times do # Run twice to verify that a second run with existing data does not change anything
            @ems.reload

            VCR.use_cassette(described_class.name.underscore + "_targeted/ec2_classic_vm_and_lb_full_refresh") do
              EmsRefresh.refresh([vm_target, lb_target])
            end
            @ems.reload

            assert_specific_flavor
            assert_specific_key_pair
            assert_specific_az
            assert_specific_security_group
            assert_specific_template
            assert_specific_load_balancer_non_vpc
            assert_specific_load_balancer_non_vpc_vms
            assert_specific_vm_powered_on
          end
        end
      end

      it "will refresh a VPC VM with floating IP and connected LBs" do
        assert_targeted_refresh_scope do
          vm_target   = InventoryRefresh::Target.new(:manager_id  => @ems.id,
                                                   :association => :vms,
                                                   :manager_ref => {:ems_ref => "i-8b5739f2"})
          lb_target_1 = InventoryRefresh::Target.new(:manager_id  => @ems.id,
                                                   :association => :load_balancers,
                                                   :manager_ref => {:ems_ref => "EmSRefreshSpecVPCELB"})
          lb_target_2 = InventoryRefresh::Target.new(:manager_id  => @ems.id,
                                                   :association => :load_balancers,
                                                   :manager_ref => {:ems_ref => "EmSRefreshSpecVPCELB2"})

          2.times do # Run twice to verify that a second run with existing data does not change anything
            @ems.reload

            VCR.use_cassette(described_class.name.underscore + "_targeted/vpc_vm_with_floating_ip_and_lbs_full_refresh") do
              EmsRefresh.refresh([vm_target, lb_target_1, lb_target_2])
            end
            @ems.reload

            assert_vpc
            assert_vpc_subnet_1
            assert_specific_flavor
            assert_specific_key_pair
            assert_specific_az
            assert_specific_security_group_on_cloud_network
            assert_specific_template
            assert_specific_load_balancer_vpc
            assert_specific_load_balancer_vpc2
            assert_specific_load_balancer_listeners_vpc_and_vpc_2
            assert_specific_cloud_volume_vm_on_cloud_network
            assert_specific_vm_on_cloud_network
          end
        end
      end

      it "will refresh a VPC VM with public IP" do
        assert_targeted_refresh_scope do
          vm_target = InventoryRefresh::Target.new(:manager_id  => @ems.id,
                                                 :association => :vms,
                                                 :manager_ref => {:ems_ref => "i-c72af2f6"})

          2.times do # Run twice to verify that a second run with existing data does not change anything
            @ems.reload

            VCR.use_cassette(described_class.name.underscore + "_targeted/vpc_vm_with_public_ip_and_template") do
              EmsRefresh.refresh([vm_target])
            end
            @ems.reload

            assert_vpc
            assert_vpc_subnet_1
            assert_specific_flavor
            assert_specific_key_pair
            assert_specific_az
            assert_specific_security_group_on_cloud_network
            assert_specific_template_2
            assert_specific_cloud_volume_vm_on_cloud_network_public_ip
            assert_specific_vm_on_cloud_network_public_ip
          end
        end
      end

      it "will refresh an orchestration stack" do
        assert_targeted_refresh_scope do
          orchestration_stack_target = InventoryRefresh::Target.new(
            :manager_id  => @ems.id,
            :association => :orchestration_stacks,
            :manager_ref => {
              :ems_ref => "arn:aws:cloudformation:us-east-1:200278856672:stack/EmsRefreshSpecStack-"\
                        "WebServerInstance-1CTHQS2P5WJ7S/d3bb46b0-2fed-11e7-a3d9-503f23fb55fe"
            }
          )

          2.times do # Run twice to verify that a second run with existing data does not change anything
            @ems.reload

            VCR.use_cassette(described_class.name.underscore + "_targeted/orchestration_stack") do
              EmsRefresh.refresh([orchestration_stack_target])
            end
            @ems.reload

            assert_specific_orchestration_template
            assert_specific_orchestration_stack_data
            assert_specific_orchestration_stack_parameters
            assert_specific_orchestration_stack_resources
            assert_specific_orchestration_stack_outputs

            # orchestration stack belongs to a provider
            expect(@orch_stack.ext_management_system).to eq(@ems)

            # orchestration stack belongs to an orchestration template
            expect(@orch_stack.orchestration_template).to eq(@orch_template)
          end
        end
      end

      it "will refresh a nested orchestration stacks" do
        assert_targeted_refresh_scope do
          orchestration_stack_target = InventoryRefresh::Target.new(
            :manager_id  => @ems.id,
            :association => :orchestration_stacks,
            :manager_ref => {
              :ems_ref => "arn:aws:cloudformation:us-east-1:200278856672:stack/EmsRefreshSpecStack/"\
                        "b4e06950-2fed-11e7-bd93-500c286374d1"
            }
          )

          orchestration_stack_target_nested = InventoryRefresh::Target.new(
            :manager_id  => @ems.id,
            :association => :orchestration_stacks,
            :manager_ref => {
              :ems_ref => "arn:aws:cloudformation:us-east-1:200278856672:stack/EmsRefreshSpecStack-"\
                        "WebServerInstance-1CTHQS2P5WJ7S/d3bb46b0-2fed-11e7-a3d9-503f23fb55fe"
            }
          )

          2.times do # Run twice to verify that a second run with existing data does not change anything
            @ems.reload

            VCR.use_cassette(described_class.name.underscore + "_targeted/orchestration_stacks_nested") do
              EmsRefresh.refresh([orchestration_stack_target, orchestration_stack_target_nested])
            end
            @ems.reload

            assert_specific_orchestration_template
            assert_specific_parent_orchestration_stack_data
            assert_specific_orchestration_stack_data
            assert_specific_orchestration_stack_parameters
            assert_specific_orchestration_stack_resources
            assert_specific_orchestration_stack_outputs

            # orchestration stack belongs to a provider
            expect(@orch_stack.ext_management_system).to eq(@ems)

            # orchestration stack belongs to an orchestration template
            expect(@orch_stack.orchestration_template).to eq(@orch_template)

            # orchestration stack can be nested
            expect(@orch_stack.parent).to eq(@parent_stack)
            expect(@parent_stack.children).to match_array([@orch_stack])
          end
        end
      end

      it "will refresh a nested orchestration stacks with Vm" do
        assert_targeted_refresh_scope do
          vm_target = InventoryRefresh::Target.new(
            :manager_id  => @ems.id,
            :association => :vms,
            :manager_ref => {:ems_ref => "i-0bca58e6e540ddc39"}
          )

          orchestration_stack_target = InventoryRefresh::Target.new(
            :manager_id  => @ems.id,
            :association => :orchestration_stacks,
            :manager_ref => {
              :ems_ref => "arn:aws:cloudformation:us-east-1:200278856672:stack/EmsRefreshSpecStack/"\
                        "b4e06950-2fed-11e7-bd93-500c286374d1"
            }
          )

          orchestration_stack_target_nested = InventoryRefresh::Target.new(
            :manager_id  => @ems.id,
            :association => :orchestration_stacks,
            :manager_ref => {
              :ems_ref => "arn:aws:cloudformation:us-east-1:200278856672:stack/EmsRefreshSpecStack-"\
                        "WebServerInstance-1CTHQS2P5WJ7S/d3bb46b0-2fed-11e7-a3d9-503f23fb55fe"
            }
          )

          2.times do # Run twice to verify that a second run with existing data does not change anything
            @ems.reload

            VCR.use_cassette(described_class.name.underscore + "_targeted/orchestration_stacks_nested_with_vm") do
              EmsRefresh.refresh([vm_target, orchestration_stack_target, orchestration_stack_target_nested])
            end
            @ems.reload

            assert_specific_orchestration_template
            assert_specific_orchestration_stack
          end
        end
      end

      it "will refresh a volume with volume_snapshot" do
        assert_targeted_refresh_scope do
          base_volume = InventoryRefresh::Target.new(
            :manager_id  => @ems.id,
            :association => :cloud_volumes,
            :manager_ref => {
              :ems_ref => "vol-0e1613cacf4688009"
            }
          )

          volume = InventoryRefresh::Target.new(
            :manager_id  => @ems.id,
            :association => :cloud_volumes,
            :manager_ref => {
              :ems_ref => "vol-0e4c86c12b28cead8"
            }
          )

          snapshot = InventoryRefresh::Target.new(
            :manager_id  => @ems.id,
            :association => :cloud_volume_snapshots,
            :manager_ref => {
              :ems_ref => "snap-055095f47fab5e749"
            }
          )

          2.times do # Run twice to verify that a second run with existing data does not change anything
            @ems.reload

            VCR.use_cassette(described_class.name.underscore + "_targeted/cloud_volume_with_snapshot") do
              EmsRefresh.refresh([base_volume, volume, snapshot])
            end
            @ems.reload

            assert_specific_cloud_volume_vm_on_cloud_network
            assert_specific_cloud_volume_snapshot
          end
        end
      end
    end
  end

  def assert_targeted_refresh_scope
    stored_table_counts = make_full_refresh

    yield

    assert_all(stored_table_counts)
  end

  def make_full_refresh
    stored_table_counts = nil

    @ems.reload
    VCR.use_cassette(described_class.name.underscore + '_inventory_object') do
      EmsRefresh.refresh(@ems)
      EmsRefresh.refresh(@ems.network_manager)
      EmsRefresh.refresh(@ems.ebs_storage_manager)

      @ems.reload
      stored_table_counts = table_counts_from_api

      assert_counts(stored_table_counts)
    end

    assert_common
    assert_mapped_tags_on_template

    stored_table_counts
  end

  def assert_all(stored_table_counts)
    assert_counts(stored_table_counts)
    assert_common
    assert_mapped_tags_on_template
  end

  def table_counts_from_api
    counts                           = super
    counts[:flavor]                  = counts[:flavor] + 5 # Graph refresh collect all flavors, not filtering them by known_flavors
    counts[:service_instances]       = 3
    counts[:service_offerings]       = 3
    counts[:service_parameters_sets] = 5
    counts
  end
end
