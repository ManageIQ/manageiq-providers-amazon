require_relative "../aws_helper"

describe ManageIQ::Providers::Amazon::CloudManager::MetricsCapture do
  let(:vm_name) { 'amazon-perf-vm' }

  let(:ems) { FactoryBot.create(:ems_amazon_with_authentication) }
  let(:vm)  { FactoryBot.build(:vm_amazon, :ems_ref => vm_name, :ext_management_system => ems) }

  context "#perf_collect_metrics" do
    it "raises an error when no EMS is defined" do
      vm = FactoryBot.build(:vm_amazon, :ext_management_system => nil)
      expect { vm.perf_collect_metrics('interval_name') }.to raise_error(RuntimeError, /No EMS defined/)
    end

    it "raises an error with no EMS credentials defined" do
      vm = FactoryBot.build(:vm_amazon, :ext_management_system => FactoryBot.create(:ems_amazon))
      expect { vm.perf_collect_metrics('interval_name') }.to raise_error(RuntimeError, /no credentials defined/)
    end

    it "handles when nothing is collected" do
      stubbed_responses = {
        :cloudwatch => {
          :list_metrics => {}
        }
      }
      with_aws_stubbed(stubbed_responses) do
        expect(vm.perf_collect_metrics('realtime')).to eq([
                                                            {"amazon-perf-vm" => described_class::VIM_STYLE_COUNTERS},
                                                            {"amazon-perf-vm" => {}}
                                                          ])
      end
    end

    it "handles when metrics are collected for only one counter" do
      stubbed_responses = {
        :cloudwatch => {
          :list_metrics          => {
            :metrics => [
              :metric_name => "NetworkIn",
              :namespace   => "Namespace"
            ]
          },
          :get_metric_statistics => {
            :datapoints => [
              :timestamp => Time.new(1999).utc,
              :average   => 1.0
            ]
          }
        }
      }
      with_aws_stubbed(stubbed_responses) do
        expect(vm.perf_collect_metrics('realtime')).to eq([
                                                            {"amazon-perf-vm" => described_class::VIM_STYLE_COUNTERS},
                                                            {"amazon-perf-vm" => {}}
                                                          ])
      end
    end
  end

  context 'counters present' do
    let(:vm_name) { 'i-091369dd8a8d470ab' }
    let(:ems) { FactoryBot.create(:ems_amazon_with_vcr_authentication, :provider_region => 'eu-central-1') }

    subject do
      with_vcr_data { vm.perf_collect_metrics('realtime').last.first.last.first.last }
    end

    it { is_expected.to have_key('mem_usage_absolute_average') }
    it { is_expected.to have_key('mem_swapped_absolute_average') }

    context 'and stored in the database' do
      let(:vm) { FactoryBot.create(:vm_amazon, :ext_management_system => ems, :name => vm_name) }

      subject do
        with_vcr_data { vm.perf_capture('realtime') }
        vm.metrics.reload.last
      end

      it { expect(subject.mem_usage_absolute_average).to_not be_nil }
      it { expect(subject.mem_swapped_absolute_average).to_not be_nil }
    end
  end

  private

  def with_vcr_data
    VCR.use_cassette(described_class.name.underscore, :allow_unused_http_interactions => true) { yield }
  end
end
