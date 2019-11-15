describe ManageIQ::Providers::Amazon::AgentCoordinatorWorker do
  describe ".ems_class" do
    it "is the cloud manager" do
      expect(described_class.ems_class).to eq(ManageIQ::Providers::Amazon::CloudManager)
    end
  end

  describe ".desired_queue_names" do
    let!(:server) { EvmSpecHelper.create_guid_miq_server_zone[1] }

    let(:zone) { server.zone }

    it "returns an empty array if no providers are created" do
      expect(described_class.desired_queue_names).to eq([])
    end

    context "with an ems" do
      before do
        FactoryBot.create(:ems_amazon_with_authentication, :zone => zone)
      end

      it "returns ems_agent_coordinator as the only queue name" do
        expect(described_class.desired_queue_names).to eq(["ems_agent_coordinator"])
      end

      it "returns a single queue for multiple emss" do
        FactoryBot.create(:ems_amazon_with_authentication, :zone => zone)
        FactoryBot.create(:ems_amazon_with_authentication, :zone => zone)
        FactoryBot.create(:ems_amazon_with_authentication, :zone => zone)

        expect(described_class.desired_queue_names).to eq(["ems_agent_coordinator"])
      end
    end
  end
end
