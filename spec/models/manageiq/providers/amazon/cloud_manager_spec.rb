require_relative 'aws_helper'

describe ManageIQ::Providers::Amazon::CloudManager do
  context ".connect with assume_role" do
    subject { FactoryBot.create(:ems_amazon_with_authentication) }

    it 'tries to assume role when given' do
      subject.default_authentication.service_account = "service_account_arn"
      expect(Aws::AssumeRoleCredentials).to receive(:new)
      subject.connect
    end

    it 'tries to not assume role when not given' do
      subject.default_authentication.service_account = nil
      expect(Aws::AssumeRoleCredentials).to_not receive(:new)
      subject.connect
    end
  end

  context ".raw_connect" do
    it "decrypts the secret access key" do
      expect(ManageIQ::Password).to receive(:try_decrypt).with('secret_access_key')

      described_class.raw_connect('access_key', 'secret_access_key', :EC2, 'region')
    end

    it "validates credentials if specified" do
      expect(described_class).to receive(:validate_connection)

      described_class.raw_connect('access_key', 'secret_access_key', :EC2, 'region', 'uri', true)
    end

    it "validates credentials with an optional uri endpoint" do
      expect(described_class).to receive(:validate_connection)
      endpoint_uri = URI.parse('https://apigateway.us-east-1.amazonaws.com')
      described_class.raw_connect('access_key', 'secret_access_key', :EC2, 'region', 'uri', true, endpoint_uri)
    end

    it "returns the connection if not specified" do
      expect(described_class.raw_connect('access_key', 'secret_access_key', :EC2, 'region', 'uri')).to be_a_kind_of(Aws::EC2::Resource)
    end
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq('ec2')
  end

  it ".description" do
    expect(described_class.description).to eq('Amazon EC2')
  end

  it "#supported_catalog_types" do
    ems = FactoryBot.create(:ems_amazon)
    expect(ems.supported_catalog_types).to eq(%w(amazon))
  end

  it "does not create orphaned network_manager" do
    ems = FactoryBot.create(:ems_amazon)
    same_ems = ExtManagementSystem.find(ems.id)

    ems.destroy
    expect(ExtManagementSystem.count).to eq(0)

    same_ems.save!
    expect(ExtManagementSystem.count).to eq(0)
  end

  it "moves the network_manager to the same zone and provider region as the cloud_manager" do
    zone1 = FactoryBot.create(:zone)
    zone2 = FactoryBot.create(:zone)

    ems = FactoryBot.create(:ems_amazon, :zone => zone1, :provider_region => "us-east-1")
    expect(ems.network_manager.zone).to eq zone1
    expect(ems.network_manager.zone_id).to eq zone1.id
    expect(ems.network_manager.provider_region).to eq "us-east-1"

    expect(ems.ebs_storage_manager.zone).to eq zone1
    expect(ems.ebs_storage_manager.zone_id).to eq zone1.id
    expect(ems.ebs_storage_manager.provider_region).to eq "us-east-1"

    if ::Settings.prototype.amazon.s3
      expect(ems.s3_storage_manager.zone).to eq zone1
      expect(ems.s3_storage_manager.zone_id).to eq zone1.id
      expect(ems.s3_storage_manager.provider_region).to eq "us-east-1"
    end

    ems.zone = zone2
    ems.provider_region = "us-west-1"
    ems.save!
    ems.reload

    expect(ems.network_manager.zone).to eq zone2
    expect(ems.network_manager.zone_id).to eq zone2.id
    expect(ems.network_manager.provider_region).to eq "us-west-1"

    expect(ems.ebs_storage_manager.zone).to eq zone2
    expect(ems.ebs_storage_manager.zone_id).to eq zone2.id
    expect(ems.ebs_storage_manager.provider_region).to eq "us-west-1"

    if ::Settings.prototype.amazon.s3
      expect(ems.s3_storage_manager.zone).to eq zone2
      expect(ems.s3_storage_manager.zone_id).to eq zone2.id
      expect(ems.s3_storage_manager.provider_region).to eq "us-west-1"
    end
  end

  describe ".metrics_collector_queue_name" do
    it "returns the correct queue name" do
      worker_queue = ManageIQ::Providers::Amazon::CloudManager::MetricsCollectorWorker.default_queue_name
      expect(described_class.metrics_collector_queue_name).to eq(worker_queue)
    end
  end

  it "#description" do
    aggregate_failures do
      ems = FactoryBot.build(:ems_amazon, :provider_region => "us-east-1")
      expect(ems.description).to eq("US East (N. Virginia)")

      ems = FactoryBot.build(:ems_amazon, :provider_region => "us-west-1")
      expect(ems.description).to eq("US West (N. California)")
    end
  end

  context "validates_uniqueness_of" do
    it "name" do
      expect { FactoryBot.create(:ems_amazon, :name => "ems_1", :provider_region => "us-east-1") }.to_not raise_error
      expect { FactoryBot.create(:ems_amazon, :name => "ems_1", :provider_region => "us-east-1") }.to     raise_error(ActiveRecord::RecordInvalid)
    end

    it "blank region" do
      expect { FactoryBot.create(:ems_amazon, :name => "ems_1", :provider_region => "") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "nil region" do
      expect { FactoryBot.create(:ems_amazon, :name => "ems_1", :provider_region => nil) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "duplicate provider_region" do
      expect { FactoryBot.create(:ems_amazon, :name => "ems_1", :provider_region => "us-east-1") }.to_not raise_error
      expect { FactoryBot.create(:ems_amazon, :name => "ems_2", :provider_region => "us-east-1") }.to_not raise_error
    end
  end

  context "translate_exception" do
    before :each do
      @ems = FactoryBot.build(:ems_amazon, :provider_region => "us-east-1")

      creds = {:default => {:userid => "fake_user", :password => "fake_password"}}
      @ems.update_authentication(creds, :save => false)
    end

    it "preserves and logs message for unknown exceptions" do
      allow(@ems).to receive(:with_provider_connection).and_raise(StandardError, "unlikely")
      expect($log).to receive(:error).with(/unlikely/)
      expect { @ems.verify_credentials }.to raise_error(MiqException::MiqHostError, /Unexpected.*unlikely/)
    end

    it "handles SignatureDoesNotMatch" do
      exception = Aws::EC2::Errors::SignatureDoesNotMatch.new(:no_context, :no_message)
      allow(@ems).to receive(:with_provider_connection).and_raise(exception)
      expect { @ems.verify_credentials }.to raise_error(MiqException::MiqHostError, /Signature.*match/)
    end

    it "handles AuthFailure" do
      exception = Aws::EC2::Errors::AuthFailure.new(:no_context, :no_message)
      allow(@ems).to receive(:with_provider_connection).and_raise(exception)
      expect { @ems.verify_credentials }.to raise_error(MiqException::MiqHostError, /Login failed/)
    end

    it "handles MissingCredentialsErrror" do
      allow(@ems).to receive(:with_provider_connection).and_raise(Aws::Errors::MissingCredentialsError)
      expect { @ems.verify_credentials }.to raise_error(MiqException::MiqHostError, /Missing credentials/i)
    end
  end

  context "#orchestration_template_validate" do
    it "validates a correct template" do
      template = FactoryBot.create(:orchestration_template_amazon_in_json)
      stubbed_aws = {:validate_template => {}}
      with_aws_stubbed(:cloudformation => stubbed_aws) do
        ems = FactoryBot.create(:ems_amazon_with_authentication)
        expect(ems.orchestration_template_validate(template)).to be_nil
      end
    end

    it "returns an error string for an incorrect template" do
      template      = FactoryBot.create(:orchestration_template_amazon_in_json)
      stubbed_aws   = {:validate_template => 'ValidationError'}
      with_aws_stubbed(:cloudformation => stubbed_aws) do
        ems = FactoryBot.create(:ems_amazon_with_authentication)
        expect(ems.orchestration_template_validate(template)).to eq('stubbed-response-error-message')
      end
    end
  end
end
