describe ManageIQ::Providers::Amazon::StorageManager::Ebs::RefreshParser do
  let(:ems)    { FactoryGirl.create(:ems_amazon_with_authentication) }
  let(:parser) { described_class.new(ems.ebs_storage_manager, Settings.ems_refresh.ec2) }

  let(:ec2_resource) { Aws::EC2::Resource.new(:stub_responses => true) }
  let(:ec2_client)   { ec2_resource.client }

  before { parser.instance_variable_set(:@aws_ec2, ec2_resource) }

  describe 'empty names replaced with ids' do
    let(:ebs_volume) do
      Aws::EC2::Volume.new(
        'def',
        :client => ec2_client,
        :name   => " \n\t ",
        :data   => { :tags => [], :attachments => [], :volume_id => 'fed' },
      )
    end
    let(:ebs_volumes) { { :volumes => [ebs_volume] } }

    before do
      allow(ec2_client).to receive(:describe_volumes).and_return(ebs_volumes)
      parser.send(:get_volumes)
    end

    let(:parser_data) { parser.instance_variable_get(:@data) }
    subject { parser_data[:cloud_volumes].first[:name] }

    it { is_expected.to eq('fed') }
  end
end
