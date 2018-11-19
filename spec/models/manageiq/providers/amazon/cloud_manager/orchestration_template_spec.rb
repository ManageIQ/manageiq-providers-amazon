describe ManageIQ::Providers::Amazon::CloudManager::OrchestrationTemplate do
  describe ".eligible_manager_types" do
    it "lists the classes of eligible managers" do
      described_class.eligible_manager_types.each do |klass|
        expect(klass <= ManageIQ::Providers::Amazon::CloudManager).to be_truthy
      end
    end
  end

  let(:json_template) { FactoryGirl.create(:orchestration_template_amazon_in_json) }
  let(:yaml_template) { FactoryGirl.create(:orchestration_template_amazon_in_yaml) }

  shared_examples_for "a template with content" do
    it "parses parameters from a template" do
      groups = template.parameter_groups
      expect(groups.size).to eq(1)
      expect(groups[0].label).to eq("Parameters")

      param_hash = groups[0].parameters.index_by(&:name)
      expect(param_hash.size).to eq(6)
      assert_aws_type(param_hash["KeyName"])
      assert_list_aws_type(param_hash["Subnets"])
      assert_list_string_type(param_hash["AZs"])
      assert_allowed_values(param_hash["WebServerInstanceType"])
      assert_min_max_value(param_hash["SecondaryIPAddressCount"])
      assert_hidden_length_pattern(param_hash["MasterUserPassword"])
    end

    it "parses resources from a template" do
      resource_types = template.resources.collect(&:type).sort!

      expect(resource_types).to eq(
        ["AWS::AutoScaling::ScalingPolicy",
         "AWS::AutoScaling::ScalingPolicy",
         "AWS::EC2::Instance",
         "AWS::EC2::SecurityGroup"]
      )
    end
  end

  describe "JSON template" do
    it_should_behave_like "a template with content" do
      let(:template) { json_template }
    end
  end

  describe "YAML template" do
    it_should_behave_like "a template with content" do
      let(:template) { yaml_template }
    end
  end

  def assert_aws_type(parameter)
    expect(parameter).to have_attributes(
      :name          => "KeyName",
      :label         => "Key Name",
      :description   => "Name of an existing EC2 KeyPair to enable SSH access to the instances",
      :data_type     => "AWS::EC2::KeyPair::KeyName",
      :default_value => nil,
      :hidden        => false,
      :required      => true,
      :constraints   => [],
    )
  end

  def assert_list_aws_type(parameter)
    expect(parameter).to have_attributes(
      :name          => "Subnets",
      :label         => "Subnets",
      :description   => "The list of SubnetIds in your Virtual Private Cloud (VPC)",
      :data_type     => "List<AWS::EC2::Subnet::Id>",
      :default_value => nil,
      :hidden        => false,
      :required      => true,
      :constraints   => [],
    )
  end

  def assert_list_string_type(parameter)
    expect(parameter).to have_attributes(
      :name          => "AZs",
      :label         => "A Zs",
      :description   => "The list of AvailabilityZones for your Virtual Private Cloud (VPC)",
      :data_type     => "List<String>",
      :default_value => nil,
      :hidden        => false,
      :required      => true,
      :constraints   => [],
    )
  end

  def assert_allowed_values(parameter)
    expect(parameter).to have_attributes(
      :name          => "WebServerInstanceType",
      :label         => "Web Server Instance Type",
      :description   => "WebServer Server EC2 instance type",
      :data_type     => "String",
      :default_value => "m1.small",
      :hidden        => false,
      :required      => true
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(1)
    expect(constraints[0]).to be_a OrchestrationTemplate::OrchestrationParameterAllowed
    expect(constraints[0]).to be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    expect(constraints[0]).to have_attributes(
      :description    => "must be a valid EC2 instance type.",
      :allowed_values => ["t2.small", "t2.medium", "m1.small"]
    )
  end

  def assert_min_max_value(parameter)
    expect(parameter).to have_attributes(
      :name          => "SecondaryIPAddressCount",
      :label         => "Secondary Ip Address Count",
      :description   => "Number of secondary IP addresses to assign to the network interface (1-5)",
      :data_type     => "Number",
      :default_value => "1",
      :hidden        => false,
      :required      => true,
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(1)
    expect(constraints[0]).to be_a OrchestrationTemplate::OrchestrationParameterRange
    expect(constraints[0]).to be_kind_of OrchestrationTemplate::OrchestrationParameterConstraint
    expect(constraints[0]).to have_attributes(
      :description => "must be a number from 1 to 5.",
      :min_value   => 1,
      :max_value   => 5
    )
  end

  def assert_hidden_length_pattern(parameter)
    expect(parameter).to have_attributes(
      :name          => "MasterUserPassword",
      :label         => "Master User Password",
      :description   => "The password associated with the aster user account for the redshift cluster that is being created. ",
      :data_type     => "String",
      :default_value => nil,
      :hidden        => true,
      :required      => true,
    )
    constraints = parameter.constraints
    expect(constraints.size).to eq(2)

    constraint_hash = constraints.index_by(&:class)
    expect(constraint_hash[OrchestrationTemplate::OrchestrationParameterPattern]).to have_attributes(
      :description => "must contain only alphanumeric characters.",
      :pattern     => "[a-zA-Z0-9]*",
    )

    expect(constraint_hash[OrchestrationTemplate::OrchestrationParameterLength]).to have_attributes(
      :description => "must contain only alphanumeric characters.",
      :min_length  => 1,
      :max_length  => 41
    )
  end

  describe '#validate_format' do
    it 'passes validation if no content' do
      template = described_class.new
      expect(template.validate_format).to be_nil
    end

    it 'passes validation with correct JSON content' do
      expect(json_template.validate_format).to be_nil
    end

    it 'passes validation with correct YAML content' do
      expect(yaml_template.validate_format).to be_nil
    end

    it 'fails validations with incorrect JSON content' do
      template = described_class.new(:content => '{"AWSTemplateFormatVersion": "2010-09-09}')
      expect(template.validate_format).not_to be_nil
    end

    it 'fails validations with incorrect YAML content' do
      template = described_class.new(:content => 'AWSTemplateFormatVersion: "2010-09-09')
      expect(template.validate_format).not_to be_nil
    end
  end

  describe '#deployment_options' do
    it 'generates deployment options for AWS' do
      options = subject.deployment_options('ManageIQ::Providers::Amazon::CloudManager')
      assert_deployment_option(options[0], "stack_name", :OrchestrationParameterPattern, true)
      assert_deployment_option(options[1], "stack_onfailure", :OrchestrationParameterAllowed, true, :reconfigurable => false)
      assert_deployment_option(options[2], "stack_timeout", nil, false, :reconfigurable => false, :data_type => 'integer')
      assert_deployment_option(options[3], "stack_notifications", nil, false)
      assert_deployment_option(options[4], "stack_capabilities", :OrchestrationParameterAllowed, false)
      assert_deployment_option(options[5], "stack_resource_types", nil, false)
      assert_deployment_option(options[6], "stack_role", nil, false)
      assert_deployment_option(options[7], "stack_tags", nil, false)
      assert_deployment_option(options[8], "stack_policy", nil, false)
    end
  end

  def assert_deployment_option(option, name, constraint_type, required, attrs = {})
    expect(option).to have_attributes(attrs.merge(:name => name))
    expect(option.required?).to eq(required)
    expect(option.constraints[0]).to be_kind_of("OrchestrationTemplate::#{constraint_type}".constantize) if constraint_type
  end
end
