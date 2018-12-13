require_relative "../../aws_refresher_spec_common"
require_relative "../../aws_refresher_spec_counts"

describe ManageIQ::Providers::Amazon::CloudManager::Refresher do
  include AwsRefresherSpecCommon
  include AwsRefresherSpecCounts

  before(:each) do
    @ems = FactoryBot.create(:ems_amazon_with_vcr_authentication)
  end

  AwsRefresherSpecCommon::ALL_GRAPH_REFRESH_SETTINGS.each do |settings|
    context "with settings #{settings}" do
      before(:each) do
        stub_refresh_settings(settings.merge(:allow_targeted_refresh => true))
        create_tag_mapping
        # The flavors are not fetched from the API, they can go in only by appliance update, so must be in place after
        # the full refresh, lets pre-create them in the DB.
        create_flavors
      end

      it "will refresh an EC2 classic VM powered on and LB full targeted refresh" do
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

          assert_counts(
            :auth_private_key  => 1,
            :availability_zone => 1,
            :cloud_volume      => 1,
            :custom_attribute  => 3,
            :disk              => 1,
            :firewall_rule     => 13,
            :flavor            => 3,
            :floating_ip       => 2,
            :hardware          => 2,
            :operating_system  => 2,
            :miq_template      => 1,
            :network           => 2,
            :network_port      => 2,
            :security_group    => 2,
            :tagging           => 1,
            :vm                => 1,
            :vm_or_template    => 2
          )
        end
      end

      it "will refresh a VPC VM with floating IP and connected LBs" do
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

          assert_counts(
            :auth_private_key  => 1,
            :availability_zone => 1,
            :cloud_network     => 1,
            :cloud_subnet      => 1,
            :cloud_volume      => 2,
            :custom_attribute  => 3,
            :disk              => 2,
            :firewall_rule     => 3,
            :flavor            => 3,
            :floating_ip       => 3,
            :hardware          => 2,
            :operating_system  => 2,
            :miq_template      => 1,
            :network           => 2,
            :network_port      => 3,
            :security_group    => 1,
            :tagging           => 1,
            :vm                => 1,
            :vm_or_template    => 2
          )
        end
      end

      it "will refresh a VPC VM with public IP" do
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

          assert_counts(
            :auth_private_key  => 1,
            :availability_zone => 1,
            :cloud_network     => 1,
            :cloud_subnet      => 1,
            :cloud_volume      => 2,
            :custom_attribute  => 2,
            :disk              => 2,
            :firewall_rule     => 3,
            :flavor            => 3,
            :floating_ip       => 1,
            :hardware          => 2,
            :operating_system  => 2,
            :miq_template      => 1,
            :network           => 2,
            :network_port      => 1,
            :security_group    => 1,
            :tagging           => 1,
            :vm                => 1,
            :vm_or_template    => 2
          )
        end
      end

      it "will refresh an orchestration stack" do
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

          assert_counts(
            :flavor                        => 3,
            :orchestration_stack           => 1,
            :orchestration_stack_output    => 1,
            :orchestration_stack_parameter => 6,
            :orchestration_stack_resource  => 2,
            :orchestration_template        => 1
          )
        end
      end

      it "will refresh a nested orchestration stacks" do
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

          assert_counts(
            :flavor                        => 3,
            :orchestration_stack           => 2,
            :orchestration_stack_output    => 2,
            :orchestration_stack_parameter => 10,
            :orchestration_stack_resource  => 19,
            :orchestration_template        => 2
          )
        end
      end

      it "will refresh a nested orchestration stacks with Vm" do
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

          assert_counts(
            :auth_private_key              => 1,
            :availability_zone             => 1,
            :cloud_network                 => 1,
            :cloud_subnet                  => 1,
            :cloud_volume                  => 1,
            :custom_attribute              => 7,
            :disk                          => 1,
            :firewall_rule                 => 3,
            :flavor                        => 3,
            :floating_ip                   => 1,
            :hardware                      => 2,
            :operating_system              => 2,
            :miq_template                  => 1,
            :network                       => 2,
            :network_port                  => 1,
            :orchestration_stack           => 2,
            :orchestration_stack_output    => 2,
            :orchestration_stack_parameter => 10,
            :orchestration_stack_resource  => 19,
            :orchestration_template        => 2,
            :security_group                => 1,
            :vm                            => 1,
            :vm_or_template                => 2
          )
        end
      end

      it "will refresh a volume with volume_snapshot" do
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

          assert_counts(
            :cloud_volume                  => 2,
            :cloud_volume_snapshot         => 1,
            :flavor                        => 3,
          )
        end
      end

      it "will refresh > 400 images in one refresh, testing we pass AWS filter max size" do
        ems_refs = ["ami-fffffa96", "ami-fffff196", "ami-ffffa785", "ami-ffff1485", "ami-fffdf295", "ami-fffd3796", "ami-fffcd0e9", "ami-fffcafe8", "ami-fffc4680", "ami-fffc0594", "ami-fffb64e9", "ami-fffb3394", "ami-fff8ba9a", "ami-fff83296", "ami-fff82482", "ami-fff7a784", "ami-fff78ce8", "ami-fff76a85", "ami-fff74c80", "ami-fff6b685", "ami-fff4b19a", "ami-fff4b080", "ami-fff45782", "ami-fff34696", "ami-fff33396", "ami-fff32894", "ami-fff2e484", "ami-fff26be8", "ami-fff22694", "ami-fff21c85", "ami-fff0c395", "ami-ffefd996", "ami-ffefc785", "ami-ffefc595", "ami-ffef4be9", "ami-ffd6b480", "ami-ffd5eb96", "ami-ffd53ee9", "ami-ffd4e284", "ami-ffd3f784", "ami-ffd3b880", "ami-ffd32fe9", "ami-ffd30494", "ami-ffd2d1e9", "ami-ffd23e92", "ami-ffd1e796", "ami-ffd1c285", "ami-ffd1bb96", "ami-ffcebd96", "ami-ffceaa85", "ami-ffce1094", "ami-ffcdff96", "ami-ffcd1d96", "ami-ffcc2194", "ami-ffcbc296", "ami-ffcb3392", "ami-ffc9aa9a", "ami-ffc97885", "ami-ffc81e94", "ami-ffc81394", "ami-ffc7e496", "ami-ffc752e8", "ami-ffc6da84", "ami-ffc62296", "ami-ffc5cf85", "ami-ffc56894", "ami-ffc567e9", "ami-ffc52b96", "ami-ffc51596", "ami-ffc512e9", "ami-ffc4ff95", "ami-ffc4c795", "ami-ffc44ee9", "ami-ffc3cfe8", "ami-ffc2b295", "ami-ffc20a96", "ami-ffc1f185", "ami-ffc1ef96", "ami-ffc12796", "ami-ffc0f9e8", "ami-ffc0ba95", "ami-ffc0ae9a", "ami-ffc08a96", "ami-ffc01996", "ami-ffbe5b85", "ami-ffbdb796", "ami-ffbd2980", "ami-ffbbfbe9", "ami-ffbae396", "ami-ffbaace9", "ami-ffba7b94", "ami-ffb99a95", "ami-ffb88de9", "ami-ffb795e8", "ami-ffb6ca95", "ami-ffb67392", "ami-ffb5cf95", "ami-ffb46a80", "ami-ffb3cf95", "ami-ffb3c59a", "ami-ffb2b496", "ami-ffb19d96", "ami-ffaefbe9", "ami-ffaef485", "ami-ffaee295", "ami-ffae03e9", "ami-ffad8884", "ami-ffad6ae9", "ami-ffac6a96", "ami-ffaa5e94", "ami-ffa94192", "ami-ffa88195", "ami-ffa85792", "ami-ffa6fa96", "ami-ffa69ee9", "ami-ffa61885", "ami-ffa5a896", "ami-ffa42896", "ami-ffa39796", "ami-ffa34d94", "ami-ffa318e8", "ami-ffa2f885", "ami-ffa2d7e8", "ami-ffa1d79a", "ami-ffa0da95", "ami-ffa09195", "ami-ffa01e80", "ami-ff9fabe9", "ami-ff9f2180", "ami-ff9e1680", "ami-ff9dc8e9", "ami-ff9ce496", "ami-ff9cc485", "ami-ff9c5394", "ami-ff9b9a96", "ami-ff9b1780", "ami-ff9affe8", "ami-ff9af896", "ami-ff98ec85", "ami-ff98afe9", "ami-ff97d5e9", "ami-ff975496", "ami-ff965192", "ami-ff95ac85", "ami-ff958196", "ami-ff94e1e9", "ami-ff9466e9", "ami-ff93e6e8", "ami-ff930e85", "ami-ff92b284", "ami-ff9296e8", "ami-ff924f94", "ami-ff922c80", "ami-ff917e96", "ami-ff8fc2e9", "ami-ff8f74e9", "ami-ff8f58e9", "ami-ff8f0894", "ami-ff8e9f84", "ami-ff8e6192", "ami-ff8e12e8", "ami-ff8b7382", "ami-ff8b6794", "ami-ff8b62e9", "ami-ff8a4994", "ami-ff896996", "ami-ff8958e9", "ami-ff86f8e9", "ami-ff86d695", "ami-ff86ba80", "ami-ff862085", "ami-ff853394", "ami-ff83a895", "ami-ff82ad95", "ami-ff82a3e8", "ami-ff81d996", "ami-ff81cd85", "ami-ff81b196", "ami-ff81a385", "ami-ff818696", "ami-ff812b96", "ami-ff811ee8", "ami-ff80eb96", "ami-ff80d795", "ami-ff80cb80", "ami-ff809a96", "ami-ff7ed294", "ami-ff7d3785", "ami-ff7d019a", "ami-ff7c6496", "ami-ff7bee85", "ami-ff7a4e85", "ami-ff79ff96", "ami-ff796795", "ami-ff792195", "ami-ff791496", "ami-ff788fe9", "ami-ff7858e8", "ami-ff782784", "ami-ff781796", "ami-ff772a9a", "ami-ff76aa85", "ami-ff768de9", "ami-ff762585", "ami-ff762496", "ami-ff760696", "ami-ff75d4e9", "ami-ff732c9a", "ami-ff729a94", "ami-ff724b96", "ami-ff6fbb94", "ami-ff6eafe9", "ami-ff6e9182", "ami-ff6e8c82", "ami-ff6e49e8", "ami-ff6defe9", "ami-ff6cfbe8", "ami-ff6c8596", "ami-ff6c4d80", "ami-ff6ae0e9", "ami-ff6a8b96", "ami-ff691785", "ami-ff68c485", "ami-ff686fe9", "ami-ff67a592", "ami-ff65f196", "ami-ff659785", "ami-ff656696", "ami-ff648396", "ami-ff645c96", "ami-ff640780", "ami-ff63aae9", "ami-ff625c96", "ami-ff625c80", "ami-ff616be9", "ami-ff614ce8", "ami-ff6126e8", "ami-ff601096", "ami-ff5f4c96", "ami-ff5e04e8", "ami-ff5cc185", "ami-ff5beb94", "ami-ff5b9094", "ami-ff59f796", "ami-ff597180", "ami-ff596095", "ami-ff59239a", "ami-ff58f796", "ami-ff588796", "ami-ff581f80", "ami-ff57b096", "ami-ff49ef85", "ami-ff49c3e8", "ami-ff498496", "ami-ff497984", "ami-ff491ce9", "ami-ff490be9", "ami-ff483480", "ami-ff47e4e9", "ami-ff47c696", "ami-ff47bf82", "ami-ff46a796", "ami-ff466c84", "ami-ff45ee94", "ami-ff458d96", "ami-ff4337e9", "ami-ff427095", "ami-ff417685", "ami-ff411096", "ami-ff40fe85", "ami-ff40df85", "ami-ff40a282", "ami-ff400180", "ami-ff3f9a94", "ami-ff3f7e80", "ami-ff3eb5e9", "ami-ff3e6be9", "ami-ff3df392", "ami-ff3d5696", "ami-ff3b4580", "ami-ff3b2b95", "ami-ff3aa5e9", "ami-ff3a4080", "ami-ff396ce9", "ami-ff36d8e9", "ami-ff366185", "ami-ff3651e8", "ami-ff35fc94", "ami-ff337380", "ami-ff32f594", "ami-ff32b996", "ami-ff326480", "ami-ff31d496", "ami-ff31b585", "ami-ff317080", "ami-ff316be8", "ami-ff313296", "ami-ff2f6985", "ami-ff2e7b9a", "ami-ff2e6195", "ami-ff2e0a84", "ami-ff2d2584", "ami-ff2ceb92", "ami-ff2c42e8", "ami-ff2bfae9", "ami-ff2be794", "ami-ff2bc296", "ami-ff2acd94", "ami-ff2aad96", "ami-ff297f95", "ami-ff295a95", "ami-ff2914e8", "ami-ff2869e9", "ami-ff281980", "ami-ff279494", "ami-ff2763e8", "ami-ff273196", "ami-ff25ba85", "ami-ff222c95", "ami-ff201085", "ami-ff1ff385", "ami-ff1fa580", "ami-ff1f4596", "ami-ff1f4085", "ami-ff1f2385", "ami-ff1e1584", "ami-ff1d9e85", "ami-ff1c38e9", "ami-ff1bfa96", "ami-ff1b9ae8", "ami-ff1ac982", "ami-ff19d596", "ami-ff192e95", "ami-ff18cb82", "ami-ff182b95", "ami-ff17fb96", "ami-ff17f892", "ami-ff174d80", "ami-ff1725e9", "ami-ff15c382", "ami-ff1555e8", "ami-ff14a685", "ami-ff142c85", "ami-ff1363e8", "ami-ff11dae9", "ami-ff101fe8", "ami-ff0f7e95", "ami-ff0f569a", "ami-ff0ece85", "ami-ff0e8ee8", "ami-ff0d7d9a", "ami-ff0c39e8", "ami-ff0ae496", "ami-ff0a5184", "ami-ff093996", "ami-ff08ef94", "ami-ff08ad94", "ami-ff07fa92", "ami-ff07cf94", "ami-ff06fc82", "ami-ff060196", "ami-ff04d585", "ami-ff04c692", "ami-ff047d95", "ami-ff042596", "ami-ff02509a", "ami-ff022b96", "ami-ff019c85", "ami-ff0147e8", "ami-ff012c85", "ami-ff006885", "ami-ff002a80", "ami-ff002080", "ami-ff001796", "ami-feffed96", "ami-feffe9e9", "ami-feff7781", "ami-feff3b96", "ami-feff0093", "ami-fefe6a84", "ami-fefe3e96", "ami-fefdcb85", "ami-fefd4f84", "ami-fefd0d97", "ami-fefbe696", "ami-fefb5096", "ami-fefa7496", "ami-fef95d84", "ami-fef848e8", "ami-fef7f4e8", "ami-fef739e8", "ami-fef66ce8", "ami-fef61597", "ami-fef59384", "ami-fef52d81", "ami-fef52684", "ami-fef50ae8", "ami-fef4e694", "ami-fef40ae8", "ami-fef27896", "ami-fef1c294", "ami-fef062e8", "ami-fef00e93", "ami-feefe996", "ami-feefc594", "ami-feed08e8", "ami-feeb4796", "ami-feea6884", "ami-feea1f93", "ami-fee98b84", "ami-fee70184", "ami-fee6c5e9", "ami-fee6ac84", "ami-fee5dc81", "ami-fee5b184", "ami-fee49881", "ami-fee44883", "ami-fee3c694", "ami-fee33981", "ami-fee2f096"]

        targets = ems_refs.map do |ems_ref|
          InventoryRefresh::Target.new(
            :manager_id  => @ems.id,
            :association => :miq_templates,
            :manager_ref => {
              :ems_ref => ems_ref
            }
          )
        end

        2.times do # Run twice to verify that a second run with existing data does not change anything
          @ems.reload

          VCR.use_cassette(described_class.name.underscore + "_targeted/more_than_400_images") do
            EmsRefresh.refresh(targets)
          end

          # The count can change after VCR refresh, if the public images are deleted, ems_ref.size doesn't have to fit
          expected_size = ems_refs.size

          assert_counts(
            :vm_or_template   => expected_size,
            :miq_template     => expected_size,
            :hardware         => expected_size,
            :operating_system => expected_size,
            :flavor           => 3,
          )
        end
      end

      it "will refresh service_offerings with parameters sets" do
        service_offering_target1 = InventoryRefresh::Target.new(
          :manager_id  => @ems.id,
          :association => :service_offerings,
          :manager_ref => {:ems_ref => "prod-4v6rc4hwaiiha"}
        )
        service_offering_target2 = InventoryRefresh::Target.new(
          :manager_id  => @ems.id,
          :association => :service_offerings,
          :manager_ref => {:ems_ref => "prod-h7p6ruq5qgrga"}
        )

        2.times do # Run twice to verify that a second run with existing data does not change anything
          @ems.reload

          VCR.use_cassette(described_class.name.underscore + "_targeted/service_offerings_with_parameters_sets") do
            EmsRefresh.refresh([service_offering_target1, service_offering_target2])
          end
          @ems.reload

          assert_specific_service_offering_with_no_portfolio
          assert_specific_service_offering_with_two_portfolios

          assert_counts(
            :flavor                  => 3,
            :service_offerings       => 2,
            :service_parameters_sets => 4,
          )

          # Lets create service parameter set, that should be disconected next refresh
          FactoryBot.create(:service_parameters_set_amazon,
                             :ems_ref               => "mock",
                             :ext_management_system => @ems,
                             :service_offering      => ServiceOffering.first)
        end
      end

      it "will refresh service_instances" do
        service_offering_target1 = InventoryRefresh::Target.new(
          :manager_id  => @ems.id,
          :association => :service_instances,
          :manager_ref => {:ems_ref => "pp-u2tepcnttldko"}
        )
        service_offering_target2 = InventoryRefresh::Target.new(
          :manager_id  => @ems.id,
          :association => :service_instances,
          :manager_ref => {:ems_ref => "pp-5pyltbgyzheqm"}
        )

        2.times do # Run twice to verify that a second run with existing data does not change anything
          @ems.reload

          VCR.use_cassette(described_class.name.underscore + "_targeted/service_instances") do
            EmsRefresh.refresh([service_offering_target1, service_offering_target2])
          end
          @ems.reload

          assert_specific_service_instance_with_rules
          assert_specific_service_instance_v3

          assert_counts(
            :flavor            => 3,
            :service_instances => 2,
          )
        end
      end
    end
  end

  def create_flavors
    FactoryBot.create(:flavor_amazon,
                       :ext_management_system    => @ems,
                       :name                     => "t1.micro",
                       :ems_ref                  => "t1.micro",
                       :description              => "T1 Micro",
                       :enabled                  => true,
                       :cpus                     => 1,
                       :cpu_cores                => 1,
                       :memory                   => 0.613.gigabytes.to_i,
                       :supports_32_bit          => true,
                       :supports_64_bit          => true,
                       :supports_hvm             => false,
                       :supports_paravirtual     => true,
                       :block_storage_based_only => true,
                       :ephemeral_disk_size      => 0,
                       :ephemeral_disk_count     => 0)

    FactoryBot.create(:flavor_amazon,
                       :ext_management_system    => @ems,
                       :name                     => "t2.micro",
                       :ems_ref                  => "t2.micro",
                       :description              => "T2 Micro",
                       :enabled                  => true,
                       :cpus                     => 1,
                       :cpu_cores                => 1,
                       :memory                   => 1.0.gigabytes.to_i,
                       :supports_32_bit          => true,
                       :supports_64_bit          => true,
                       :supports_hvm             => false,
                       :supports_paravirtual     => true,
                       :block_storage_based_only => true,
                       :ephemeral_disk_size      => 0,
                       :ephemeral_disk_count     => 0)

    FactoryBot.create(:flavor_amazon,
                       :ext_management_system    => @ems,
                       :name                     => "t2.nano",
                       :ems_ref                  => "t2.nano",
                       :description              => "T2 Nano",
                       :enabled                  => true,
                       :cpus                     => 1,
                       :cpu_cores                => 1,
                       :memory                   => 0.5.gigabytes,
                       :supports_32_bit          => true,
                       :supports_64_bit          => true,
                       :supports_hvm             => false,
                       :supports_paravirtual     => true,
                       :block_storage_based_only => true,
                       :ephemeral_disk_size      => 0,
                       :ephemeral_disk_count     => 0)
  end
end
