describe ManageIQ::Providers::Amazon::InstanceTypes do
  context "disable instance_types via Settings" do
    it "contains t2.nano without it being disabled" do
      allow(Settings.ems.ems_amazon).to receive(:disabled_instance_types).and_return([])
      expect(described_class.names).to include("t2.nano")
    end

    it "does not contain t2.nano that is disabled" do
      allow(Settings.ems.ems_amazon).to receive(:disabled_instance_types).and_return(['t2.nano'])
      expect(described_class.names).not_to include('t2.nano')
    end
  end

  context "add instance_types via Settings" do
    let(:additional) do
      {
        "makeups.xlarge"  => {
          :name        => "makeups.xlarge",
          :family      => "Compute Optimized",
          :description => "Cluster Compute Quadruple Extra Large",
          :memory      => 23.gigabytes,
          :vcpu        => 16,
        },
        "makeups.2xlarge" => {
          :name        => "makeups.2xlarge",
          :family      => "Compute Optimized",
          :description => "Cluster Compute Quadruple Extra Large",
          :memory      => 23.gigabytes,
          :vcpu        => 32,
        },
      }
    end

    context "with no additional instance_types set" do
      let(:settings) do
        {:ems => {:ems_amazon => {:additional_instance_types => nil}}}
      end

      it "returns standard instance_types" do
        stub_settings(settings)
        expect(described_class.names).not_to include("makeups.xlarge", "makeups.2xlarge")
      end
    end

    context "with additional" do
      let(:settings) do
        {:ems => {:ems_amazon => {:additional_instance_types => additional}}}
      end

      it "returns the custom instance_types" do
        stub_settings(settings)
        expect(described_class.names).to include("makeups.xlarge", "makeups.2xlarge")
      end
    end

    context "with additional instance_types and disabled instance_types" do
      let(:settings) do
        {
          :ems => {
            :ems_amazon => {
              :disabled_instance_types   => ["makeups.2xlarge"],
              :additional_instance_types => additional
            }
          }
        }
      end

      it "disabled_instance_types overrides additional_instance_types" do
        stub_settings(settings)
        expect(described_class.names).to     include("makeups.xlarge")
        expect(described_class.names).not_to include("makeups.2xlarge")
      end
    end
  end
end
