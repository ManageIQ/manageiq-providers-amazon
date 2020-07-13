# frozen_string_literal: true

begin
  require 'awesome_print'
rescue LoadError
end

namespace 'aws:extract' do
  desc 'Get / renew instance types and details list from AWS Price List Bulk API'
  task :instance_types do
    require_relative 'lib/aws_products_data_collector'
    require_relative 'lib/aws_instance_data_parser'

    data_dir = ManageIQ::Providers::Amazon::Engine.root.join('db/fixtures')
    data_dir.mkpath
    out_file = data_dir.join('aws_instance_types.yml')

    # weird cache logging issue workaround
    I18n.backend = I18n.backend.backend unless Rails.initialized?

    LOGGER = Logger.new(STDOUT)
    LOGGER.info("NOTE: use 'aws:cache:clear' task to clear the cache")
    AwsProductsDataCollector.cache.logger = LOGGER

    def log_data(header, data, level: :warn)
      return if data.empty?
      severity = Logger.const_get(level.to_s.upcase)
      LOGGER.log(severity) do
        lines = []
        lines << header
        lines << (defined?(AwesomePrint) ? data.ai : JSON.pretty_generate(data))
        lines.join("\n")
      end
    end

    ## get, parse, and sort data

    products_data, collecting_warnings = AwsProductsDataCollector.new(
      :service_name       => 'AmazonEC2',
      :product_families   => 'Compute Instance', # 'Dedicated Host' == bare metal: "m5", "p3", etc.
      :product_attributes => AwsInstanceDataParser::REQUIRED_ATTRIBUTES,
      :folding_attributes => 'instanceType',
      :mutable_attributes => %w(currentVersion currentGeneration).freeze,
    ).result

    parsing_warnings = {}

    types_data = products_data.map do |product_data|
      instance_data, warnings = AwsInstanceDataParser.new(product_data).result
      parsing_warnings.merge!(warnings) { |_, old, new| old + new }
      [product_data['instanceType'], instance_data.deep_dup]
    end.to_h

    ## consider previous data

    old_types_data = YAML.load_file(out_file)
    default_type = old_types_data.find { |_, data| data[:default] }.first
    discontinued_types = (old_types_data.keys - types_data.keys)
    types_data.merge!(old_types_data.slice(*discontinued_types))

    ## postprocess

    types_data.each do |instance_type, instance_data|
      instance_data.except!(:default, :deprecated, :discontinued, :disabled)
      instance_data[:default] = true if instance_type == default_type
      if discontinued_types.include?(instance_type) || !instance_data[:current_version]
        instance_data[:discontinued] = true
        instance_data[:disabled] = true
      end
      if instance_data[:current_version] && !instance_data[:current_generation]
        instance_data[:deprecated] = true
      end
    end

    types_data.sort!
    types_data.each_value do |type_data|
      type_data.sort!
      type_data.each_value { |value| value.try(:sort!) }
    end

    ## show warnings

    unless collecting_warnings.empty?
      info = collecting_warnings.transform_keys(&:first)
      info.each_value do |instance_data|
        instance_data.transform_values!(&:to_a)
      end
      info.sort!
      log_data('Attention! Contradictory products data:', info)
    end
    log_data('Attention! Unforeseen values format:', parsing_warnings)

    ## save data

    out_file.write(types_data.to_yaml)
  end
end
