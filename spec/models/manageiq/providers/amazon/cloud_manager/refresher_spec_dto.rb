require_relative "../aws_refresher_spec_common"

describe ManageIQ::Providers::Amazon::CloudManager::Refresher do
  include AwsRefresherSpecCommon

  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_amazon, :zone => zone)
    @ems.update_authentication(:default => {:userid => "0123456789ABCDEFGHIJ", :password => "ABCDEFGHIJKLMNO1234567890abcdefghijklmno"})
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ec2)
  end

  # Test all kinds of DTO refreshes, DTO refresh, DTO with batch saving
  [{:dto_batch_saving => true, :dto_refresh => true},
   {:dto_batch_saving => false, :dto_refresh => true},
  ].each do |dto_settings|
    before(:each) do
      settings = OpenStruct.new
      settings.dto_batch_saving   = dto_settings[:dto_batch_saving]
      settings.dto_refresh        = dto_settings[:dto_refresh]
      settings.get_private_images = true
      settings.get_shared_images  = true
      settings.get_public_images  = false

      allow(Settings.ems_refresh).to receive(:ec2).and_return(settings)
      allow(Settings.ems_refresh).to receive(:ec2_network).and_return(dto_settings)
    end

    context "with settings #{dto_settings}" do
      it "will perform a full refresh" do
        2.times do # Run twice to verify that a second run with existing data does not change anything
          @ems.reload

          VCR.use_cassette(described_class.name.underscore) do
            EmsRefresh.refresh(@ems)
            EmsRefresh.refresh(@ems.network_manager)
          end
          @ems.reload

          assert_common
        end
      end
    end
  end

  def expected_table_counts
    super.merge({
                  :flavor => 57 # DTO collect all flavors, not filtering them by known_flavors
                })
  end
end
