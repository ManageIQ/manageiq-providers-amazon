require_relative 'aws_helper'
require_relative 'aws_stubs'

describe ManageIQ::Providers::Amazon::Provider do
  before do
    @provider_regions = ['us-east-1', 'us-east-2']
    _, _, @zone = EvmSpecHelper.create_guid_miq_server_zone

    @provider = FactoryGirl.create(:provider_amazon, :zone => @zone, :provider_regions => @provider_regions)

    @original_ids = extract_ids @provider.cloud_managers
  end

  it "provider creates managers" do
    expect(@provider.default_authentication).not_to be_nil
    expect(@provider.s3_storage_manager).not_to be_nil
    expect(@provider.cloud_managers.count).to eq(@provider_regions.count)
    expect(@provider.provider_regions).to eq(@provider_regions)
  end

  it "provider adds/deletes cloud managers for regions (no intersection)" do
    # assign same regions
    @provider.provider_regions = @provider_regions

    expect(@provider.cloud_managers.count).to eq(@provider_regions.count)
    expect(extract_ids @provider.cloud_managers).to eq(@original_ids)
    expect(@provider.provider_regions).to eq(@provider_regions)

    # assign other regions (no intersection)
    provider_regions2 = ['us-west-1', 'us-west-2', 'ap-southeast-1']
    @provider.provider_regions = provider_regions2

    expect(@provider.cloud_managers.count).to eq(provider_regions2.count)
    expect(ManageIQ::Providers::Amazon::CloudManager.count).to eq(provider_regions2.count)
    expect(@provider.provider_regions).to eq(provider_regions2)
  end

  it "provider adds/deletes cloud managers for regions (with intersection)" do
    # assign additional region
    @provider.provider_regions = ['us-east-1', 'us-east-2', 'ap-southeast-1']

    expect(@provider.cloud_managers.count).to eq(3)
    expect(extract_ids @provider.cloud_managers).to include(*@original_ids)
  end

  it "managers use provider's authentication" do
    expect(Authentication.count).to eq(1) # all managers share provider's credentials

    expect(@provider.s3_storage_manager.default_authentication).not_to be_nil
    expect(@provider.s3_storage_manager.default_authentication.id).to eq(@provider.default_authentication.id)

    @provider.cloud_managers.each do |el|
      expect(el.default_authentication).not_to be_nil
      expect(el.default_authentication.id).to eq(@provider.default_authentication.id)
    end
  end

  it "cloud manager lists s3 manager as well" do
    @s3_manager = @provider.s3_storage_manager
    @provider.cloud_managers.each do |el|
      expect(el.s3_storage_manager).not_to be_nil
      expect(el.s3_storage_manager.id).to eq(@provider.s3_storage_manager.id)
      expect(extract_ids(el.storage_managers)).to include(@s3_manager.id)
    end
  end

  it "s3 manager points to no cloud manager" do
    expect(@provider.s3_storage_manager.parent_manager).to be_nil
  end

  it "provider regions to string" do
    expect(@provider.provider_regions.join(",")).to eq("us-east-1,us-east-2")

    @provider.provider_regions = []

    expect(@provider.provider_regions.join(",")).to eq("")
  end

  private

  def extract_ids(objects)
    objects.map{|el| el.id}
  end

end
