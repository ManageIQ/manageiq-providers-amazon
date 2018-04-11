require_relative "../../aws_refresher_spec_common"
require_relative "../../aws_refresher_spec_counts"

describe ManageIQ::Providers::Amazon::CloudManager::Refresher do
  include AwsRefresherSpecCommon
  include AwsRefresherSpecCounts

  before(:each) do
    @ems = FactoryGirl.create(:ems_amazon_with_vcr_authentication)
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ec2)
  end

  # Test all kinds of DTO refreshes, DTO refresh, DTO with recursive saving strategy
  [{:inventory_object_refresh => true},
   {:inventory_object_saving_strategy => :recursive, :inventory_object_refresh => true},].each do |inventory_object_settings|
    context "with settings #{inventory_object_settings}" do
      before(:each) do
        settings                                  = OpenStruct.new
        settings.inventory_object_saving_strategy = inventory_object_settings[:inventory_object_saving_strategy]
        settings.inventory_object_refresh         = inventory_object_settings[:inventory_object_refresh]
        settings.get_private_images               = true
        settings.get_shared_images                = true
        settings.get_public_images                = false
        settings.ignore_terminated_instances      = true

        allow(Settings.ems_refresh).to receive(:ec2).and_return(settings)
        allow(Settings.ems_refresh).to receive(:ec2_network).and_return(inventory_object_settings)
      end

      it "will perform a full refresh" do
        2.times do # Run twice to verify that a second run with existing data does not change anything
          @ems.reload
          VCR.use_cassette(described_class.name.underscore + '_inventory_object') do
            EmsRefresh.refresh(@ems)
            EmsRefresh.refresh(@ems.network_manager)
            EmsRefresh.refresh(@ems.ebs_storage_manager)

            @ems.reload
            assert_counts(table_counts_from_api)
          end

          assert_common
        end
      end
    end
  end

  def table_counts_from_api
    counts = super
    counts[:flavor] = counts[:flavor] + 4 # Graph refresh collect all flavors, not filtering them by known_flavors
    counts
  end
end
