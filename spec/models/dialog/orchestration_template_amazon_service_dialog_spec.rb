describe "OrchestrationTemplateServiceDialog for Amazon" do
  let(:dialog_service)  { Dialog::OrchestrationTemplateServiceDialog.new }
  let(:template_amazon) { FactoryGirl.create(:orchestration_template_amazon_in_json) }

  describe "#create_dialog" do
    it "creates a dialog from CloudFormation template with stack basic info and parameters" do
      dialog = dialog_service.create_dialog("test", template_amazon)

      tabs = dialog.dialog_tabs
      assert_stack_group(tabs[0].dialog_groups[0])
    end
  end

  def assert_stack_group(group)
    expect(group).to have_attributes(
      :label   => "Options",
      :display => "edit",
    )

    fields = group.dialog_fields
    expect(fields.size).to eq(10)

    expect(fields[0].resource_action.fqname).to eq('/Cloud/Orchestration/Operations/Methods/Available_Tenants')
    assert_field(fields[0], DialogFieldDropDownList, :name => 'tenant_name',          :dynamic => true)
    assert_field(fields[1], DialogFieldTextBox,      :name => 'stack_name',           :validator_rule => '^[A-Za-z][A-Za-z0-9\-]*$')
    assert_field(fields[2], DialogFieldDropDownList, :name => 'stack_onfailure',      :values => [%w(DELETE Delete\ stack), %w(DO_NOTHING Do\ nothing), %w(ROLLBACK Rollback)])
    assert_field(fields[3], DialogFieldTextBox,      :name => 'stack_timeout',        :data_type => 'integer')
    assert_field(fields[4], DialogFieldTextAreaBox,  :name => 'stack_notifications',  :data_type => 'string')
    assert_field(fields[5], DialogFieldDropDownList, :name => 'stack_capabilities',   :values => [[nil, '<None>'], ['CAPABILITY_IAM'] * 2, ['CAPABILITY_NAMED_IAM'] * 2])
    assert_field(fields[6], DialogFieldTextBox,      :name => 'stack_resource_types', :data_type => 'string')
    assert_field(fields[7], DialogFieldTextBox,      :name => 'stack_role',           :data_type => 'string')
    assert_field(fields[8], DialogFieldTextBox,      :name => 'stack_tags',           :data_type => 'string')
    assert_field(fields[9], DialogFieldTextBox,      :name => 'stack_policy',         :data_type => 'string')
  end

  def assert_field(field, clss, attributes)
    expect(field).to be_kind_of clss
    expect(field).to have_attributes(attributes)
  end
end
