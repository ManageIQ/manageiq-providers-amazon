describe ManageIQ::Providers::Amazon::AgentCoordinatorWorker do
  describe ".ems_class" do
    it "is the cloud manager" do
      expect(described_class.ems_class).to eq(ManageIQ::Providers::Amazon::CloudManager)
    end
  end

  describe ".has_required_role?" do
    before        { ServerRole.seed }
    let!(:server) { EvmSpecHelper.create_guid_miq_server_zone[1] }
    let(:zone)    { server.zone }

    it "returns an empty array if no providers are created" do
      expect(described_class.has_required_role?).to be_falsy
    end

    context "with an ems" do
      before do
        FactoryBot.create(:ems_amazon_with_authentication, :zone => zone)
      end

      context "with smartproxy role disabled" do
        it "returns false" do
          expect(described_class.has_required_role?).to be_falsy
        end
      end

      context "with smartproxy role enabled" do
        before do
          server.update(:has_vix_disk_lib => true)
          server.role = "smartproxy"
          server.assigned_server_roles.update(:active => true)
        end

        it "returns true" do
          expect(described_class.has_required_role?).to be_truthy
        end

        it "returns true with multiple emss" do
          FactoryBot.create(:ems_amazon_with_authentication, :zone => zone)
          FactoryBot.create(:ems_amazon_with_authentication, :zone => zone)
          FactoryBot.create(:ems_amazon_with_authentication, :zone => zone)

          expect(described_class.has_required_role?).to be_truthy
        end
      end
    end
  end
end
