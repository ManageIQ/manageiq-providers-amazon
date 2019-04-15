require_relative '../../models/manageiq/providers/amazon/aws_helper'
require_relative '../../models/manageiq/providers/amazon/aws_stubs'

describe ManageIQ::Providers::Amazon::CloudManager::Refresher do
  include AwsStubs

  describe "refresh" do
    before(:each) do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems                 = FactoryBot.create(:ems_amazon, :zone => zone, :name => ems_name)
      @ems.update_authentication(:default => {:userid => "0123456789", :password => "ABCDEFGHIJKL345678efghijklmno"})
    end

    let(:ec2_user) { FactoryBot.build(:authentication).userid }
    let(:ec2_pass) { FactoryBot.build(:authentication).password }
    let(:ec2_user_other) { 'user_other' }
    let(:ec2_pass_other) { 'pass_other' }
    subject { described_class.discover(ec2_user, ec2_pass) }

    before do
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)
    end

    before(:all) do
      output = ["Name", "Object Count", "Scaling", "Collect", "Parse Inventory", "Parse Targetted", "Saving", "Total"]

      open(Rails.root.join('log', 'benchmark_results.csv'), 'a') do |f|
        f.puts output.join(",")
      end
    end

    [1].each do |data_scaling|
      context "with data scaled for #{data_scaling}" do
        let(:data_scaling) { data_scaling }

        context "with inventory_object" do
          let(:ems_name) { "inventory_object_ems_scaled_#{data_scaling}x" }
          it "will perform a full refresh" do
            @inventory_object_settings                = {:inventory_object_saving_strategy => nil, :inventory_object_refresh => true}
            settings                                  = OpenStruct.new
            settings.inventory_object_refresh         = @inventory_object_settings[:inventory_object_refresh]
            settings.inventory_object_saving_strategy = @inventory_object_settings[:inventory_object_saving_strategy]
            settings.get_private_images               = true
            settings.get_shared_images                = false
            settings.get_public_images                = false

            allow(Settings.ems_refresh).to receive(:ec2).and_return(settings)

            refresh
          end
        end

        context "with recursive saving inventory_object" do
          let(:ems_name) { "non_bached_inventory_object_ems_scaled_#{data_scaling}x" }

          it "will perform a full refresh" do
            @inventory_object_settings                = {:inventory_object_saving_strategy => :recursive, :inventory_object_refresh => true}
            settings                                  = OpenStruct.new
            settings.inventory_object_refresh         = @inventory_object_settings[:inventory_object_refresh]
            settings.inventory_object_saving_strategy = @inventory_object_settings[:inventory_object_saving_strategy]
            settings.get_private_images               = true
            settings.get_shared_images                = false
            settings.get_public_images                = false

            allow(Settings.ems_refresh).to receive(:ec2).and_return(settings)

            refresh
          end
        end

        context "with non inventory_object" do
          let(:ems_name) { "non_inventory_object_ems_scaled_#{data_scaling}x" }

          it "will perform a full refresh" do
            @inventory_object_settings                = {:inventory_object_refresh => false}
            settings                                  = OpenStruct.new
            settings.inventory_object_refresh         = @inventory_object_settings[:inventory_object_refresh]
            settings.inventory_object_saving_strategy = @inventory_object_settings[:inventory_object_saving_strategy]
            settings.get_private_images               = true
            settings.get_shared_images                = false
            settings.get_public_images                = false

            allow(Settings.ems_refresh).to receive(:ec2).and_return(settings)

            refresh
          end
        end
      end
    end
  end

  def test_counts(scaling = nil)
    scaling ||= scaling_factor

    super.merge({
                  :instance_vpc_count    => scaling * 8000,
                  :instance_ec2_count    => scaling * 2000,
                  :image_count           => scaling * 30000,
                  :key_pair_count        => scaling * 200,
                  :stack_count           => scaling * 800,
                  :stack_resource_count  => scaling * 40,
                  :stack_parameter_count => scaling * 20,
                  :stack_output_count    => scaling * 20,
                })
  end

  def refresh
    scaling = scaling_factor
    # Test data creation
    with_aws_stubbed(stub_responses) do
      EmsRefresh.refresh(@ems)
    end
    @ems.reload
    write_benchmark_results(scaling, 'Creating data')

    assert_table_counts
    assert_ems

    # Test data updating, running refresh with same AP Idata, should just update
    with_aws_stubbed(stub_responses) do
      EmsRefresh.refresh(@ems)
    end
    @ems.reload
    write_benchmark_results(scaling, 'Updating data')

    assert_table_counts
    assert_ems

    # Test data deleting, nullifying what API returns should invoke delete of all the data
    @data_scaling         = 0
    @disconnect_inv_count = 1
    with_aws_stubbed(stub_responses) do
      EmsRefresh.refresh(@ems)
    end
    @ems.reload
    write_benchmark_results(scaling, 'Deleting data')

    assert_table_counts
    assert_ems
  end

  def write_benchmark_results(scaling, subname)
    detected = File.readlines(Rails.root.join('log', 'evm.log')).reverse_each.detect do |s|
      s.include?(ems_name) && s.include?("Complete - Timings")
    end

    open(Rails.root.join('log', 'benchmark_results.log'), 'a') do |f|
      f.puts detected
    end

    # Get also a chart displayable format
    matched = detected.match(/:collect_inventory_for_targets=>([\d\.e-]+).*?
                              :parse_inventory=>([\d\.e-]+).*?
                              :parse_targeted_inventory=>([\d\.e-]+).*?
                              :save_inventory=>([\d\.e-]+).*?
                              :ems_refresh=>([\d\.e-]+).*?/x)
    output  = []
    output << "#{ems_name} - #{subname}"
    output << expected_table_counts.values.sum
    output << scaling
    output += matched[1..5].map { |x| x.to_f.round(2) }
    open(Rails.root.join('log', 'benchmark_results.csv'), 'a') do |f|
      f.puts output.join(",")
    end
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
    disconnect                      ||= disconnect_inv_factor
    vm_count                        = test_counts[:instance_vpc_count] + test_counts[:instance_ec2_count]
    image_count                     = test_counts[:image_count]

    # Disconnect_inv count, when these objects are not found in the API, they are not deleted in DB, but just marked
    # as disconnected
    vm_count_plus_disconnect_inv    = vm_count + disconnect * (test_counts(1)[:instance_vpc_count] +
      test_counts(1)[:instance_ec2_count])
    image_count_plus_disconnect_inv = image_count + disconnect * test_counts(1)[:image_count]

    {
      :auth_private_key                  => test_counts[:key_pair_count],
      :ext_management_system             => 4,
      # TODO(lsmola) collect all flavors for original refresh
      :flavor                            => @inventory_object_settings[:inventory_object_refresh] ? 78 : 76,
      :availability_zone                 => 5,
      :vm_or_template                    => vm_count_plus_disconnect_inv + image_count_plus_disconnect_inv,
      :vm                                => vm_count_plus_disconnect_inv,
      :miq_template                      => image_count_plus_disconnect_inv,
      :disk                              => vm_count_plus_disconnect_inv,
      :guest_device                      => 0,
      :hardware                          => vm_count_plus_disconnect_inv + image_count_plus_disconnect_inv,
      :network                           => vm_count_plus_disconnect_inv * 2,
      :operating_system                  => 0,
      :snapshot                          => 0,
      :system_service                    => 0,
      # :relationship                      => vm_count_plus_disconnect_inv + image_count_plus_disconnect_inv,
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
      :custom_attribute                  => 0,
      :load_balancer                     => 0,
      :load_balancer_pool                => 0,
      :load_balancer_pool_member         => 0,
      :load_balancer_pool_member_pool    => 0,
      :load_balancer_listener            => 0,
      :load_balancer_listener_pool       => 0,
      :load_balancer_health_check        => 0,
      :load_balancer_health_check_member => 0,
    }
  end

  def assert_table_counts
    actual = {
      :auth_private_key                  => ManageIQ::Providers::CloudManager::AuthKeyPair.count,
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
    }

    expect(actual).to eq expected_table_counts
  end

  def assert_ems
    ems = @ems

    expect(ems).to have_attributes(
                     :api_version => nil, # TODO: Should be 3.0
                     :uid_ems     => nil
                   )

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
