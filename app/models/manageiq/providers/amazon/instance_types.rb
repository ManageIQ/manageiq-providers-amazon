# frozen_string_literal: true

module ManageIQ::Providers::Amazon::InstanceTypes
  ALL_TYPES = YAML.load_file(
    ManageIQ::Providers::Amazon::Engine.root.join('db/fixtures/aws_instance_types.yml')
  )

  # Types that are still advertised, but not recommended for new instances.
  DEPRECATED_TYPES = ALL_TYPES.select do |_, attrs|
    attrs[:deprecated] && !attrs[:discontinued]
  end.to_h

  # Types that are no longer advertised
  DISCONTINUED_TYPES = ALL_TYPES.select do |_, attrs|
    !attrs[:deprecated] && attrs[:discontinued]
  end.to_h

  # Types that are currently advertised for use
  AVAILABLE_TYPES = ALL_TYPES.except(*(DEPRECATED_TYPES.keys + DISCONTINUED_TYPES.keys))

  def self.instance_types
    additional = Hash(Settings.ems.ems_amazon.try!(:additional_instance_types)).stringify_keys
    disabled = Array(Settings.ems.ems_amazon.try!(:disabled_instance_types))

    instance_types = ALL_TYPES.merge(additional).except(*disabled)
    instance_types.default = ALL_TYPES["unknown"]
    instance_types
  end

  def self.all
    instance_types.values
  end

  def self.names
    instance_types.keys
  end
end
