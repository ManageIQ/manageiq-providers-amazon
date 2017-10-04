require_relative 'aws_helper'

describe ManageIQ::Providers::Amazon::CloudManager do
  context ".raw_connect" do
    it "decrypts the secret access key" do
      expect(MiqPassword).to receive(:try_decrypt).with('secret_access_key')

      described_class.raw_connect('access_key', 'secret_access_key', :EC2, 'region')
    end

    it "validates credentials if specified" do
      expect(described_class).to receive(:validate_connection)

      described_class.raw_connect('access_key', 'secret_access_key', :EC2, 'region', 'uri', true)
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

  it "does not create orphaned network_manager" do
    ems = FactoryGirl.create(:ems_amazon)
    same_ems = ExtManagementSystem.find(ems.id)

    ems.destroy
    expect(ExtManagementSystem.count).to eq(0)

    same_ems.save!
    expect(ExtManagementSystem.count).to eq(0)
  end

  it "moves the network_manager to the same zone and provider region as the cloud_manager" do
    zone1 = FactoryGirl.create(:zone)
    zone2 = FactoryGirl.create(:zone)

    ems = FactoryGirl.create(:ems_amazon, :zone => zone1, :provider_region => "us-east-1")
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

  describe ".discover" do
    let(:ec2_user) { FactoryGirl.build(:authentication).userid }
    let(:ec2_pass) { FactoryGirl.build(:authentication).password }
    let(:ec2_user_other) { 'user_other' }
    let(:ec2_pass_other) { 'pass_other' }
    subject { described_class.discover(ec2_user, ec2_pass) }

    before do
      EvmSpecHelper.local_miq_server(:zone => Zone.seed)
    end

    around do |example|
      with_aws_stubbed(:ec2 => stub_responses) do
        example.run
      end
    end

    def assert_region(ems, name)
      expect(ems.name).to eq(name)
      expect(ems.provider_region).to eq(name.split(" ").first)
      expect(ems.auth_user_pwd).to eq([ec2_user, ec2_pass])
    end

    def assert_region_on_another_account(ems, name)
      expect(ems.name).to eq(name)
      expect(ems.provider_region).to eq(name.split(" ").first)
      expect(ems.auth_user_pwd).to eq([ec2_user_other, ec2_pass_other])
    end

    context "on greenfield amazon" do
      let(:stub_responses) do
        {
          :describe_regions => {
            :regions => [
              {:region_name => 'us-east-1'},
              {:region_name => 'us-west-1'},
            ]
          }
        }
      end

      it "with no existing records only creates default ems" do
        expect(subject.count).to eq(1)

        emses = ManageIQ::Providers::Amazon::CloudManager.order(:name)
        expect(emses.count).to eq(1)
        assert_region(emses[0], "us-east-1")
      end
    end

    context "on amazon with two populated regions" do
      let(:stub_responses) do
        {
          :describe_regions   => {
            :regions => [
              {:region_name => 'us-east-1'},
              {:region_name => 'us-west-1'},
            ]
          },
          :describe_instances => {
            :reservations => [
              {
                :instances => [
                  {:instance_id => "id-1"},
                  {:instance_id => "id-2"},
                ]
              }
            ]
          }
        }
      end

      it "with no existing records" do
        expect(subject.count).to eq(2)

        emses = ManageIQ::Providers::Amazon::CloudManager.order(:name)
        expect(emses.count).to eq(2)
        assert_region(emses[0], "us-east-1")
        assert_region(emses[1], "us-west-1")
      end

      it "with some existing records" do
        FactoryGirl.create(:ems_amazon_with_authentication, :name => "us-west-1", :provider_region => "us-west-1")

        expect(subject.count).to eq(1)

        emses = ManageIQ::Providers::Amazon::CloudManager.order(:name)
        expect(emses.count).to eq(2)
        assert_region(emses[0], "us-east-1")
        assert_region(emses[1], "us-west-1")
      end

      it "with all existing records" do
        FactoryGirl.create(:ems_amazon_with_authentication, :name => "us-east-1", :provider_region => "us-east-1")
        FactoryGirl.create(:ems_amazon_with_authentication, :name => "us-west-1", :provider_region => "us-west-1")

        expect(subject.count).to eq(0)

        emses = ManageIQ::Providers::Amazon::CloudManager.order(:name)
        expect(emses.count).to eq(2)
        assert_region(emses[0], "us-east-1")
        assert_region(emses[1], "us-west-1")
      end

      context "with records on other account" do
        def create_ems_on_other_account(name)
          cloud_manager = FactoryGirl.create(:ems_amazon,
                                             :name            => name,
                                             :provider_region => "us-west-1")
          cloud_manager.authentications << FactoryGirl.create(:authentication, :userid => ec2_user_other, :password => ec2_pass_other)
        end

        it "with the same name" do
          create_ems_on_other_account("us-west-1")
          expect(subject.count).to eq(2)

          emses = ManageIQ::Providers::Amazon::CloudManager.order(:name).includes(:authentications)
          expect(emses.count).to eq(3)
          assert_region(emses[0], "us-east-1")
          assert_region_on_another_account(emses[1], "us-west-1")
          assert_region(emses[2], "us-west-1 #{ec2_user}")
        end

        it "with the same name and backup name" do
          create_ems_on_other_account("us-west-1")
          create_ems_on_other_account("us-west-1 #{ec2_user}")

          expect(subject.count).to eq(2)

          emses = ManageIQ::Providers::Amazon::CloudManager.order(:name).includes(:authentications)
          expect(emses.count).to eq(4)
          assert_region(emses[0], "us-east-1")
          assert_region_on_another_account(emses[1], "us-west-1")
          assert_region_on_another_account(emses[3], "us-west-1 #{ec2_user}")
          assert_region(emses[2], "us-west-1 1")
        end

        it "with the same name, backup name, and secondary backup name" do
          create_ems_on_other_account("us-west-1")
          create_ems_on_other_account("us-west-1 #{ec2_user}")
          create_ems_on_other_account("us-west-1 1")

          expect(subject.count).to eq(2)

          emses = ManageIQ::Providers::Amazon::CloudManager.order(:name).includes(:authentications)
          expect(emses.count).to eq(5)
          assert_region(emses[0], "us-east-1")
          assert_region_on_another_account(emses[1], "us-west-1")
          assert_region_on_another_account(emses[4], "us-west-1 #{ec2_user}")
          assert_region_on_another_account(emses[2], "us-west-1 1")
          assert_region(emses[3], "us-west-1 2")
        end
      end
    end
  end

  it "#description" do
    ems = FactoryGirl.build(:ems_amazon, :provider_region => "us-east-1")
    expect(ems.description).to eq("US East (Northern Virginia)")

    ems = FactoryGirl.build(:ems_amazon, :provider_region => "us-west-1")
    expect(ems.description).to eq("US West (Northern California)")
  end

  context "validates_uniqueness_of" do
    it "name" do
      expect { FactoryGirl.create(:ems_amazon, :name => "ems_1", :provider_region => "us-east-1") }.to_not raise_error
      expect { FactoryGirl.create(:ems_amazon, :name => "ems_1", :provider_region => "us-east-1") }.to     raise_error(ActiveRecord::RecordInvalid)
    end

    it "blank region" do
      expect { FactoryGirl.create(:ems_amazon, :name => "ems_1", :provider_region => "") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "nil region" do
      expect { FactoryGirl.create(:ems_amazon, :name => "ems_1", :provider_region => nil) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "duplicate provider_region" do
      expect { FactoryGirl.create(:ems_amazon, :name => "ems_1", :provider_region => "us-east-1") }.to_not raise_error
      expect { FactoryGirl.create(:ems_amazon, :name => "ems_2", :provider_region => "us-east-1") }.to_not raise_error
    end
  end

  context "translate_exception" do
    before :each do
      @ems = FactoryGirl.build(:ems_amazon, :provider_region => "us-east-1")

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
      template = FactoryGirl.create(:orchestration_template_amazon_in_json)
      stubbed_aws = {:validate_template => {}}
      with_aws_stubbed(:cloudformation => stubbed_aws) do
        ems = FactoryGirl.create(:ems_amazon_with_authentication)
        expect(ems.orchestration_template_validate(template)).to be_nil
      end
    end

    it "returns an error string for an incorrect template" do
      template      = FactoryGirl.create(:orchestration_template_amazon_in_json)
      stubbed_aws   = {:validate_template => 'ValidationError'}
      with_aws_stubbed(:cloudformation => stubbed_aws) do
        ems = FactoryGirl.create(:ems_amazon_with_authentication)
        expect(ems.orchestration_template_validate(template)).to eq('stubbed-response-error-message')
      end
    end
  end
end
