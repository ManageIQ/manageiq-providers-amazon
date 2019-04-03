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

  context 'counters gathered' do
    let(:ems) { FactoryBot.create(:ems_amazon_with_vcr_authentication, :provider_region => 'eu-central-1') }

    subject do
      with_vcr_data(cassette_suffix) do
        _vim_counters, aws_counters = vm.perf_collect_metrics('realtime')
        aws_counters.dig(vm_name, sample_datetime)
      end
    end

    context 'from linux old way' do
      let(:cassette_suffix) { nil }
      let(:sample_datetime) { '2018-01-18T08:10:20Z' }
      let(:expected_metrics) do
        {
          'mem_usage_absolute_average'   => 8.91695700387728, # 'MemoryUtilization'
          'mem_swapped_absolute_average' => 0.0,              # 'SwapUtilization'
        }
      end
      it { should include expected_metrics }
    end

    context 'from windows with agent' do
      let(:cassette_suffix) { 'win2016' }
      let(:sample_datetime) { '2019-03-29T10:50:20Z' }
      let(:expected_metrics) do
        {
          'mem_usage_absolute_average'   => 91.24837493896484, # 'Memory % Committed Bytes In Use'
          'mem_swapped_absolute_average' => 73.10266876220703, # 'Paging File % Usage'
        }
      end
      it { should include expected_metrics }
    end

    context 'from linux with agent' do
      let(:cassette_suffix) { 'ami2' }
      let(:sample_datetime) { '2019-04-02T13:58:40Z' }
      let(:expected_metrics) do
        {
          'mem_usage_absolute_average'   => 91.47303753181924,  # 'mem_used_percent'
          'mem_swapped_absolute_average' => 23.339932784777773, # 'swap_used_percent'
        }
      end
      it { should include expected_metrics }
    end

    context 'and stored in the database' do
      let(:vm) { FactoryBot.create(:vm_amazon, :ext_management_system => ems) }

      subject do
        with_vcr_data { vm.perf_capture('realtime') }
        vm.metrics.reload.last
      end

      it { expect(subject.mem_usage_absolute_average).to_not be_nil }
      it { expect(subject.mem_swapped_absolute_average).to_not be_nil }
    end
  end

  private

  def with_vcr_data(suffix = nil)
    casette_name = described_class.name.underscore
    casette_name = "#{casette_name}-#{suffix}" if suffix
    VCR.use_cassette(casette_name, :allow_unused_http_interactions => true) { yield }
  end
end
