describe ManageIQ::Providers::Amazon::ContainerManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('eks')
  end

  it ".description" do
    expect(described_class.description).to eq('Amazon EKS')
  end

  context "#pause!" do
    let(:zone) { FactoryBot.create(:zone) }
    let(:ems)  { FactoryBot.create(:ems_amazon, :zone => zone) }

    include_examples "ExtManagementSystem#pause!"
  end

  context "#resume!" do
    let(:zone) { FactoryBot.create(:zone) }
    let(:ems)  { FactoryBot.create(:ems_amazon, :zone => zone) }

    include_examples "ExtManagementSystem#resume!"
  end
end
