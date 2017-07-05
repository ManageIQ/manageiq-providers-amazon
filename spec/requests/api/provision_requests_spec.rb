describe "Provision Requests API" do
  context "AWS advanced provision requests" do
    let!(:aws_dialog) do
      path = Rails.root.join("product", "dialogs", "miq_dialogs", "miq_provision_amazon_dialogs_template.yaml")
      content = YAML.load_file(path)[:content]
      dialog = FactoryGirl.create(:miq_dialog, :name => "miq_provision_amazon_dialogs_template",
                                  :dialog_type => "MiqProvisionWorkflow", :content => content)
      allow_any_instance_of(MiqRequestWorkflow).to receive(:dialog_name_from_automate).and_return(dialog.name)
    end
    let(:ems) { FactoryGirl.create(:ems_amazon_with_authentication) }
    let(:template) do
      FactoryGirl.create(:template_amazon, :name => "template1", :ext_management_system => ems)
    end
    let(:flavor) do
      FactoryGirl.create(:flavor_amazon, :ems_id => ems.id, :name => 't2.small', :cloud_subnet_required => true)
    end
    let(:az)             { FactoryGirl.create(:availability_zone_amazon, :ems_id => ems.id) }
    let(:cloud_network1) do
      FactoryGirl.create(:cloud_network_amazon,
                         :ext_management_system => ems.network_manager,
                         :enabled               => true)
    end
    let(:cloud_subnet1) do
      FactoryGirl.create(:cloud_subnet,
                         :ext_management_system => ems.network_manager,
                         :cloud_network         => cloud_network1,
                         :availability_zone     => az)
    end
    let(:security_group1) do
      FactoryGirl.create(:security_group_amazon,
                         :name                  => "sgn_1",
                         :ext_management_system => ems.network_manager,
                         :cloud_network         => cloud_network1)
    end
    let(:floating_ip1) do
      FactoryGirl.create(:floating_ip_amazon,
                         :cloud_network_only    => true,
                         :ext_management_system => ems.network_manager,
                         :cloud_network         => cloud_network1)
    end

    let(:provreq_body) do
      {
        "template_fields" => {"guid" => template.guid},
        "requester"       => {
          "owner_first_name" => "John",
          "owner_last_name"  => "Doe",
          "owner_email"      => "user@example.com"
        }
      }
    end

    let(:expected_provreq_attributes) { %w(id options) }

    let(:expected_provreq_hash) do
      {
        "userid"         => api_config(:user),
        "requester_name" => api_config(:user_name),
        "approval_state" => "pending_approval",
        "type"           => "MiqProvisionRequest",
        "request_type"   => "template",
        "message"        => /Provisioning/i,
        "status"         => "Ok"
      }
    end

    it "supports manual placement" do
      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      body = provreq_body.merge(
        "vm_fields" => {
          "vm_name"                     => "api_test_aws",
          "instance_type"               => flavor.id,
          "placement_auto"              => false,
          "placement_availability_zone" => az.id,
          "cloud_network"               => cloud_network1.id,
          "cloud_subnet"                => cloud_subnet1.id,
          "security_groups"             => security_group1.id,
          "floating_ip_address"         => floating_ip1.id
        }
      )

      run_post(provision_requests_url, body)

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_provreq_attributes)
      expect_results_to_match_hash("results", [expected_provreq_hash])

      expect(response.parsed_body["results"].first).to a_hash_including(
        "options" => a_hash_including(
          "placement_auto"              => [false, 0],
          "placement_availability_zone" => [az.id, az.name],
          "cloud_network"               => [cloud_network1.id, cloud_network1.name],
          "cloud_subnet"                => [cloud_subnet1.id, anything],
          "security_groups"             => [security_group1.id, security_group1.name],
          "floating_ip_address"         => [floating_ip1.id, floating_ip1.name]
        )
      )

      task_id = ApplicationRecord.uncompress_id(response.parsed_body["results"].first["id"])
      expect(MiqProvisionRequest.exists?(task_id)).to be_truthy
    end

    it "does not process manual placement data if placement_auto is not set" do
      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      body = provreq_body.merge(
        "vm_fields" => {
          "vm_name"                     => "api_test_aws",
          "instance_type"               => flavor.id,
          "placement_availability_zone" => az.id
        }
      )

      run_post(provision_requests_url, body)

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_provreq_attributes)
      expect_results_to_match_hash("results", [expected_provreq_hash])

      expect(response.parsed_body["results"].first).to a_hash_including(
        "options" => a_hash_including(
          "placement_auto"              => [true, 1],
          "placement_availability_zone" => [nil, nil]
        )
      )

      task_id = ApplicationRecord.uncompress_id(response.parsed_body["results"].first["id"])
      expect(MiqProvisionRequest.exists?(task_id)).to be_truthy
    end

    it "does not process manual placement data if placement_auto is set to true" do
      api_basic_authorize collection_action_identifier(:provision_requests, :create)

      body = provreq_body.merge(
        "vm_fields" => {
          "vm_name"                     => "api_test_aws",
          "instance_type"               => flavor.id,
          "placement_auto"              => true,
          "placement_availability_zone" => az.id
        }
      )

      run_post(provision_requests_url, body)

      expect(response).to have_http_status(:ok)
      expect_result_resources_to_include_keys("results", expected_provreq_attributes)
      expect_results_to_match_hash("results", [expected_provreq_hash])

      expect(response.parsed_body["results"].first).to a_hash_including(
        "options" => a_hash_including(
          "placement_auto"              => [true, 1],
          "placement_availability_zone" => [nil, nil]
        )
      )

      task_id = ApplicationRecord.uncompress_id(response.parsed_body["results"].first["id"])
      expect(MiqProvisionRequest.exists?(task_id)).to be_truthy
    end
  end
end
