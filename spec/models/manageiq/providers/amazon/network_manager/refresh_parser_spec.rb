describe ManageIQ::Providers::Amazon::NetworkManager::RefreshParser do
  require 'aws-sdk'
  let(:ems) { FactoryGirl.create(:ems_amazon_with_authentication) }
  let(:parser) { described_class.new(ems.network_manager, Settings.ems_refresh.ec2_network) }

  describe "#parse_firewall_rule" do
    let(:perm)         { Aws::EC2::Types::IpPermission.new(rule_options) }
    let(:ip_protocol)  { "icmp" }
    let(:ip_ranges)    { [] }
    let(:ipv_6_ranges) { [] }
    let(:rule_options) do
      {
        :ip_protocol         => ip_protocol,
        :ip_ranges           => ip_ranges.map    { |ip| Aws::EC2::Types::IpRange.new(:cidr_ip => ip) },
        :ipv_6_ranges        => ipv_6_ranges.map { |ip| Aws::EC2::Types::Ipv6Range.new(:cidr_ipv_6 => ip) },
        :user_id_group_pairs => []
      }
    end
    subject { parser.send(:parse_firewall_rule, perm, 'inbound') }

    context "all ip_protocols" do
      let(:ip_protocol) { -1 }
      let(:ip_ranges) { ["1.1.1.0/24"] }

      it { is_expected.to all(include(:host_protocol => "All")) }
    end

    context "ipv6 ranges" do
      let(:ipv_6_ranges) { ["2001:DB8::0/120", "2001:DB8::80/122"] }

      it { expect(subject.length).to eq(2) }
      it { expect(subject.collect { |i| i[:source_ip_range] }).to eq(ipv_6_ranges) }
    end

    context "ipv4 ranges" do
      let(:ip_ranges) { ["10.0.0.0/24", "10.0.1.0/24"] }

      it { expect(subject.length).to eq(2) }
      it { expect(subject.collect { |i| i[:source_ip_range] }).to eq(ip_ranges) }
    end
  end

  describe 'empty names replaced with ids' do
    let(:ec2_resource) { Aws::EC2::Resource.new(:stub_responses => true) }
    let(:vpc) do
      Aws::EC2::Vpc.new(
        'asd',
        :client => ec2_resource.client,
        :name   => " \t \n ",
        :data   => { :tags => [], :vpc_id => 'sdf' },
      )
    end

    before do
      parser.instance_variable_set(:@aws_ec2, ec2_resource)
      allow(ec2_resource.client).to receive(:describe_vpcs).and_return(:vpcs => [vpc])
      parser.send(:get_cloud_networks)
    end

    let(:parser_data) { parser.instance_variable_get(:@data) }
    subject { parser_data[:cloud_networks].first[:name] }

    it { is_expected.to eq('sdf') }
  end
end
