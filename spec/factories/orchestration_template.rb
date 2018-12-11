FactoryBot.define do
  factory :orchestration_template_amazon,
          :parent => :orchestration_template,
          :class  => "ManageIQ::Providers::Amazon::CloudManager::OrchestrationTemplate" do
    sequence(:content) { |n| "{\"AWSTemplateFormatVersion\" : \"version(#{seq_padded_for_sorting(n)})\"}" }
  end

  factory :orchestration_template_amazon_with_stacks, :parent => :orchestration_template_amazon do
    stacks { [FactoryBot.create(:orchestration_stack)] }
  end

  factory :orchestration_template_amazon_in_json, :parent => :orchestration_template_amazon do
    content File.read(ManageIQ::Providers::Amazon::Engine.root.join(*%w(spec fixtures orchestration_templates cfn_parameters.json)))
  end

  factory :orchestration_template_amazon_in_yaml, :parent => :orchestration_template_amazon do
    content File.read(ManageIQ::Providers::Amazon::Engine.root.join(*%w(spec fixtures orchestration_templates cfn_parameters.yaml)))
  end
end
