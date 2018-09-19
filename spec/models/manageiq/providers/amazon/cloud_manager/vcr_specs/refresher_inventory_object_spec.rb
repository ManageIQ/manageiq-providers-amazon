require_relative "../../aws_refresher_spec_common"
require_relative "../../aws_refresher_spec_counts"

describe ManageIQ::Providers::Amazon::CloudManager::Refresher do
  include AwsRefresherSpecCommon
  include AwsRefresherSpecCounts

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ec2)
  end

  AwsRefresherSpecCommon::ALL_GRAPH_REFRESH_SETTINGS.each do |settings|
    context "with settings #{settings}" do
      before(:each) do
        stub_refresh_settings(settings)
        create_tag_mapping

        @ems = FactoryGirl.create(:ems_amazon_with_vcr_authentication)
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

  it 'pickups existing Vm and MiqTemplate records on Amazon EMS re-adding' do
    ems = new_amazon_ems

    VCR.use_cassette(described_class.name.underscore + '_vm_reconnect') do
      expect { EmsRefresh.refresh(ems) }.to change { VmOrTemplate.count }.from(0)
    end

    expect { ems.destroy }.to_not change { VmOrTemplate.count }

    aggregate_failures do
      expect(Vm.count).to_not be_zero
      expect(MiqTemplate.count).to_not be_zero
      expect(ExtManagementSystem.count).to be_zero
    end

    ems = new_amazon_ems

    VCR.use_cassette(described_class.name.underscore + '_vm_reconnect') do
      expect { EmsRefresh.refresh(ems) }
        .to change { VmOrTemplate.distinct.pluck(:ems_id) }.from([nil]).to([ems.id])
        .and change { VmOrTemplate.count }.by(0)
        .and change { MiqTemplate.count }.by(0)
        .and change { Vm.count }.by(0)
    end
  end

  def table_counts_from_api
    counts                           = super
    counts[:flavor]                  = counts[:flavor] + 5 # Graph refresh collect all flavors, not filtering them by known_flavors
    counts[:service_instances]       = 3
    counts[:service_offerings]       = 3
    counts[:service_parameters_sets] = 5
    counts
  end

  def new_amazon_ems
    FactoryGirl.create(:ems_amazon_with_vcr_authentication, :provider_region => 'eu-central-1')
  end
end
