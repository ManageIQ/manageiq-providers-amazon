require_relative '../aws_helper'
require_relative '../aws_stubs'
require_relative '../aws_refresher_spec_common'

describe ManageIQ::Providers::Amazon::NetworkManager::Refresher do
  include AwsRefresherSpecCommon
  include AwsStubs

  describe "refresh" do
    before do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      @ems                 = FactoryBot.create(:ems_amazon, :zone => zone)
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

        context "OrchestrationStack refresh" do
          context "with all empty relations" do
            let(:mocked_stack_parameters) { nil }
            let(:mocked_stack_resources) { nil }
            let(:mocked_stack_outputs) { nil }

            it "tests refresh passes" do
              with_aws_stubbed(stub_responses) do
                EmsRefresh.refresh(@ems)
              end


              expect(OrchestrationStack.count).to eq test_counts[:stack_count]
              expect(OrchestrationStackParameter.count).to eq 0
              expect(OrchestrationStackResource.count).to eq 0
              expect(OrchestrationStackOutput.count).to eq 0
            end
          end

          context "with empty parameters relation" do
            let(:mocked_stack_parameters) { nil }

            it "tests refresh passes" do
              with_aws_stubbed(stub_responses) do
                EmsRefresh.refresh(@ems)
              end

              expect(OrchestrationStack.count).to eq test_counts[:stack_count]
              expect(OrchestrationStackParameter.count).to eq 0
              expect(OrchestrationStackResource.count).to eq test_counts[:stack_count] * test_counts[:stack_resource_count]
              expect(OrchestrationStackOutput.count).to eq test_counts[:stack_count] * test_counts[:stack_output_count]
            end
          end

          context "with empty outputs relation" do
            let(:mocked_stack_outputs) { nil }

            it "tests refresh passes" do
              with_aws_stubbed(stub_responses) do
                EmsRefresh.refresh(@ems)
              end

              expect(OrchestrationStack.count).to eq test_counts[:stack_count]
              expect(OrchestrationStackParameter.count).to eq test_counts[:stack_count] * test_counts[:stack_parameter_count]
              expect(OrchestrationStackResource.count).to eq test_counts[:stack_count] * test_counts[:stack_resource_count]
              expect(OrchestrationStackOutput.count).to eq 0
            end
          end

          context "with empty resources relation" do
            let(:mocked_stack_resources) { nil }

            it "tests refresh passes" do
              with_aws_stubbed(stub_responses) do
                EmsRefresh.refresh(@ems)
              end

              expect(OrchestrationStack.count).to eq test_counts[:stack_count]
              expect(OrchestrationStackParameter.count).to eq test_counts[:stack_count] * test_counts[:stack_parameter_count]
              expect(OrchestrationStackResource.count).to eq 0
              expect(OrchestrationStackOutput.count).to eq test_counts[:stack_count] * test_counts[:stack_output_count]
            end
          end
        end
      end
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
end
