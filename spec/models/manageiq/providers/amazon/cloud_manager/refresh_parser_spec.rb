describe ManageIQ::Providers::Amazon::CloudManager::RefreshParser do
  let(:ems) { FactoryGirl.create(:ems_amazon_with_authentication) }
  let(:parser) { described_class.new(ems, Settings.ems_refresh.ec2) }
  let(:client) { parser.instance_variable_get(:@aws_ec2).client }

  describe "#get_public_images" do
    subject { parser.send(:get_public_images) }

    context "default filter" do
      let(:default_filter) { Settings.ems_refresh[ems.class.ems_type].to_hash[:public_images_filters] }

      require 'aws-sdk'
      before do
        parser.instance_variable_set(:@aws_ec2, Aws::EC2::Resource.new(:stub_responses => true))
      end

      it "gets applied" do
        expect(client).to receive(:describe_images)
          .with(hash_including(:filters => default_filter))
          .and_return(client.stub_data(:describe_images))

        subject
      end

      it "validated by SDK" do
        is_expected.to eq([])
      end
    end
  end

  describe 'empty names replaced with ids' do
    let(:cf_resource) { Aws::CloudFormation::Resource.new(:stub_responses => true) }
    let(:cf_stack) do
      Aws::CloudFormation::Stack.new(
        :client => cf_resource.client,
        :name   => " \t ",
        :data   => { :outputs => [], :parameters => [], :stack_id => 'abc' },
      )
    end

    before do
      parser.instance_variable_set(:@aws_cloud_formation, cf_resource)
      allow(cf_resource).to receive(:stacks).and_return([cf_stack])
      parser.send(:get_stacks)
    end

    let(:parser_data) { parser.instance_variable_get(:@data) }
    subject { parser_data[:orchestration_stacks].first[:name] }

    it { is_expected.to eq('abc') }
  end
end
