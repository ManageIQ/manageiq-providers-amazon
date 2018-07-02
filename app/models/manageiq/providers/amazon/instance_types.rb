# frozen_string_literal: true

# NOTE: use 'aws:extract:instance_types' rake task to renew the list

module ManageIQ::Providers::Amazon::InstanceTypes
  ALL_TYPES = YAML.load_file(
    ManageIQ::Providers::Amazon::Engine.root.join('db/fixtures/aws_instance_types.yml')
  ).each_value(&:freeze).freeze

  # Types that are still advertised, but not recommended for new instances.
  DEPRECATED_TYPES = ALL_TYPES.select do |_, attrs|
    attrs[:deprecated] == true && !attrs[:discontinued]
  end.to_h.freeze

  # Types that are no longer advertised
  DISCONTINUED_TYPES = ALL_TYPES.select do |_, attrs|
    !attrs[:deprecated] && attrs[:discontinued] == true
  end.to_h.freeze

  # Types that are currently advertised for use
  AVAILABLE_TYPES = ALL_TYPES.except(*(DEPRECATED_TYPES.keys + DISCONTINUED_TYPES.keys)).freeze

  def self.instance_types
    additional = Hash(Settings.ems.ems_amazon.try!(:additional_instance_types)).stringify_keys
    disabled = Array(Settings.ems.ems_amazon.try!(:disabled_instance_types))
    ALL_TYPES.merge(additional).except(*disabled)
  end

  def self.all
    instance_types.values
  end

  def self.names
    instance_types.keys
  end
end
