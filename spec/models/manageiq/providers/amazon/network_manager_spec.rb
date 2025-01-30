require_relative 'aws_helper'

describe ManageIQ::Providers::Amazon::NetworkManager do
  context "ems" do
    it "does not support network creation" do
      ems = described_class.new
      expect(ems.supports?(:update)).to eq(false)
    end
  end

  context "singleton methods" do
    it "returns the expected value for the description method" do
      expect(described_class.description).to eq('Amazon EC2 Network')
    end

    it "returns the expected value for the ems_type method" do
      expect(described_class.ems_type).to eq('ec2_network')
    end

    it "returns the expected value for the hostname_required? method" do
      expect(described_class.hostname_required?).to eq(false)
    end

    it "returns the expected value for the display_name method" do
      expect(described_class.display_name).to eq('Network Provider (Amazon)')
      expect(described_class.display_name(2)).to eq('Network Providers (Amazon)')
    end
  end
end
