describe ManageIQ::Providers::Amazon::Regions do
  it "has all the regions" do
    ems = FactoryBot.create(:ems_amazon_with_vcr_authentication)

    # TODO: use `slice` on 2.5
    current_regions = described_class.regions.select do |name, _config|
      !described_class::SPECIAL_REGIONS.include?(name)
    end.map do |_name, config|
      { :region_name => config[:name], :endpoint => config[:hostname] }
    end

    online_regions = VCR.use_cassette(described_class.name.underscore) do
      ems.connect.client.describe_regions.to_h[:regions]
    end

    # sort for better diff
    [current_regions, online_regions].each do |regions|
      regions.map!     { |r| r.sort.to_h     }
      regions.sort_by! { |r| r[:region_name] }
    end

    expect(online_regions).to eq(current_regions)
  end

  context "disable regions via Settings" do
    it "contains gov_cloud without it being disabled" do
      allow(Settings.ems.ems_amazon).to receive(:disabled_regions).and_return([])
      expect(described_class.names).to include("us-gov-west-1")
    end

    it "contains gov_cloud without disabled_regions being set at all - for backwards compatibility" do
      allow(Settings.ems).to receive(:ems_amazon).and_return(nil)
      expect(described_class.names).to include("us-gov-west-1")
    end

    it "does not contain some regions that are disabled" do
      allow(Settings.ems.ems_amazon).to receive(:disabled_regions).and_return(['us-gov-west-1'])
      expect(described_class.names).not_to include('us-gov-west-1')
    end
  end

  context "add regions via settings" do
    context "with no additional regions set" do
      let(:settings) do
        {:ems => {:ems_amazon => {:additional_regions => nil}}}
      end

      it "returns standard regions" do
        stub_settings(settings)
        expect(described_class.names).to eql(described_class::REGIONS.keys)
      end
    end

    context "with one additional" do
      let(:settings) do
        {
          :ems => {
            :ems_amazon => {
              :additional_regions => {
                :"my-custom-region" => {
                  :name => "My First Custom Region"
                }
              }
            }
          }
        }
      end

      it "returns the custom regions" do
        stub_settings(settings)
        expect(described_class.names).to include("my-custom-region")
      end
    end

    context "with additional regions and disabled regions" do
      let(:settings) do
        {
          :ems => {
            :ems_amazon => {
              :disabled_regions   => ["my-custom-region-2"],
              :additional_regions => {
                :"my-custom-region-1" => {
                  :name => "My First Custom Region"
                },
                :"my-custom-region-2" => {
                  :name => "My Second Custom Region"
                }
              }
            }
          }
        }
      end

      it "disabled_regions overrides additional_regions" do
        stub_settings(settings)
        expect(described_class.names).to     include("my-custom-region-1")
        expect(described_class.names).not_to include("my-custom-region-2")
      end
    end
  end
end
