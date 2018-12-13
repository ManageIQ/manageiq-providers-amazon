require_relative '../aws_helper'

describe ManageIQ::Providers::Amazon::CloudManager::Vm do
  let(:ems) { FactoryBot.create(:ems_amazon_with_authentication) }
  let(:vm)  { FactoryBot.create(:vm_amazon, :ems_ref => "amazon-perf-vm", :ext_management_system => ems) }

  context "#active_proxy?" do
    it "returns true" do
      expect(vm.has_active_proxy?).to eq(true)
    end
  end

  context "#has_proxy?" do
    it "returns true" do
      expect(vm.has_proxy?).to eq(true)
    end
  end

  context "#scan_via_ems?" do
    it "returns true" do
      expect(vm.scan_via_ems?).to eq(true)
    end
  end

  context "#requires_storage_for_scan??" do
    it "returns false" do
      expect(vm.requires_storage_for_scan?).to eq(false)
    end
  end

  context "#proxies4job" do
    before do
      allow(MiqServer).to receive(:my_server).and_return("default")
      @proxies = vm.proxies4job
    end

    it "has the correct message" do
      expect(@proxies[:message]).to eq('Perform SmartState Analysis on this Instance')
    end

    it "returns the default proxy" do
      expect(@proxies[:proxies].first).to eq('default')
    end
  end

  context "#is_available?" do
    let(:power_state_on)        { "running" }
    let(:power_state_suspended) { "pending" }

    context("with :start") do
      let(:state) { :start }
      include_examples "Vm operation is available when not powered on"
    end

    context("with :stop") do
      let(:state) { :stop }
      include_examples "Vm operation is available when powered on"
    end

    context("with :suspend") do
      let(:state) { :suspend }
      include_examples "Vm operation is not available"
    end

    context("with :pause") do
      let(:state) { :pause }
      include_examples "Vm operation is not available"
    end

    context("with :shutdown_guest") do
      let(:state) { :shutdown_guest }
      include_examples "Vm operation is not available"
    end

    context("with :standby_guest") do
      let(:state) { :standby_guest }
      include_examples "Vm operation is not available"
    end

    context("with :reboot_guest") do
      let(:state) { :reboot_guest }
      include_examples "Vm operation is available when powered on"
    end

    context("with :reset") do
      let(:state) { :reset }
      include_examples "Vm operation is not available"
    end
  end

  describe "#set_custom_field" do
    it "updates a tag on an instance" do
      stubbed_responses = {
        :ec2 => {
          :describe_instances =>
                                 { :reservations => [{:instances => [:instance_id => vm.ems_ref]}] }
        }
      }
      with_aws_stubbed(stubbed_responses) do
        expect(vm.set_custom_field('tag_key', 'tag_value')).to be_truthy
      end
    end
  end
end
