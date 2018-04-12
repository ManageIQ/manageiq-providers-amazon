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

  AwsRefresherSpecCommon::ALL_REFRESH_SETTINGS.each do |settings|
    context "with settings #{settings}" do
      before(:each) do
        stub_refresh_settings(settings)
        create_tag_mapping
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
          assert_mapped_tags_on_template
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
