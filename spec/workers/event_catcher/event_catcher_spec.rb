require 'kubeclient'
require 'recursive-open-struct'
require 'aws-sdk-sts'

require_relative '../../../workers/event_catcher/event_catcher'

RSpec.describe EventCatcher do
  let(:ems) do
    {
      'id'       => 42,
      'uid_ems'  => 'my-eks-cluster',
      'type'     => 'ManageIQ::Providers::Amazon::ContainerManager',
      'ems_type' => 'eks'
    }
  end
  let(:endpoint)       { {'hostname' => 'eks.example.com', 'port' => 443} }
  let(:authentication) { {'authtype' => 'default', 'userid' => 'AKIAIOSFODNN7EXAMPLE', 'password' => 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'} }
  let(:settings)       { {'ems' => {'ems_eks' => {'blacklisted_event_names' => []}}} }
  let(:logger)         { instance_double('Logger', :info => nil, :warn => nil) }
  let(:catcher)        { described_class.new(ems, endpoint, authentication, settings, {}, logger) }

  describe '#log_prefix' do
    it 'returns the Amazon class name' do
      expect(catcher.send(:log_prefix)).to eq('MIQ(ManageIQ::Providers::Amazon::ContainerManager::EventCatcher)')
    end
  end

  describe '#auth_options' do
    let(:fake_token) { 'k8s-aws-v1.fake-sts-token' }

    before do
      allow(Kubeclient::AmazonEksCredentials).to receive(:token).and_return(fake_token)
    end

    it 'calls AmazonEksCredentials.token with the access key, secret, and cluster name' do
      expect(Kubeclient::AmazonEksCredentials).to receive(:token) do |credentials, cluster_name|
        expect(credentials).to be_a(Aws::Credentials)
        expect(credentials.access_key_id).to eq('AKIAIOSFODNN7EXAMPLE')
        expect(credentials.secret_access_key).to eq('wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY')
        expect(cluster_name).to eq('my-eks-cluster')
        fake_token
      end

      catcher.send(:auth_options)
    end

    it 'returns a bearer_token hash' do
      expect(catcher.send(:auth_options)).to eq(:bearer_token => fake_token)
    end

    it 'sets @token_expiry to the expiry time from token creation' do
      now = Time.now.utc
      allow(Time).to receive(:now).and_return(now)
      catcher.send(:auth_options)
      expect(catcher.token_expiry).to eq(now + described_class::TOKEN_TTL)
    end
  end

  describe '#token_expiry' do
    it 'returns nil before auth_options is called' do
      expect(catcher.token_expiry).to be_nil
    end
  end

  describe '#build_client' do
    let(:fake_token) { 'k8s-aws-v1.fresh-token' }
    let(:client)     { instance_double('Kubeclient::Client', :discover => nil) }

    before do
      allow(Kubeclient::AmazonEksCredentials).to receive(:token).and_return(fake_token)
    end

    it 'passes auth_options result to Kubeclient::Client' do
      expect(Kubeclient::Client).to receive(:new) do |_uri, _version, opts|
        expect(opts[:auth_options]).to eq(:bearer_token => fake_token)
        client
      end

      catcher.send(:build_client)
    end

    it 'calls AmazonEksCredentials.token on every build_client call (token refresh)' do
      allow(Kubeclient::Client).to receive(:new).and_return(client)
      expect(Kubeclient::AmazonEksCredentials).to receive(:token).twice

      catcher.send(:build_client)
      catcher.send(:build_client)
    end
  end
end
