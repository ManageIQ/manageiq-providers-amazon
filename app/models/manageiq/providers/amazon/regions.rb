# frozen_string_literal: true

# NOTE: use 'aws:extract:regions' rake task to renew the list

require 'yaml'

module ManageIQ
  module Providers::Amazon
    module Regions
      REGIONS = YAML.load_file(
        ManageIQ::Providers::Amazon::Engine.root.join('db/fixtures/aws_regions.yml')
      ).each_value(&:freeze).freeze

      # https://github.com/aws/aws-sdk-ruby/blob/5fe5795e8910bb667996dfc75e4f16b7e69e3980/gems/aws-partitions/partitions.json#L11
      ORDINARY_REGIONS_REGEXP = /^(us|eu|ap|sa|ca)\-\w+\-\d+$/

      # https://docs.aws.amazon.com/general/latest/gr/rande.html - see quotes below
      SPECIAL_REGIONS = begin
        atypical_regions = [
          'ap-northeast-3', # "To request access to the Asia Pacific (Osaka-Local) Region, contact..."
          'ap-east-1',      # "you must manually enable before you can use..."
        ].freeze
        REGIONS.keys.select { |name| atypical_regions.include?(name) || name !~ ORDINARY_REGIONS_REGEXP }
      end.freeze

      def self.regions
        additional_regions = Hash(Settings.ems.ems_amazon.try!(:additional_regions)).stringify_keys
        disabled_regions   = Array(Settings.ems.ems_amazon.try!(:disabled_regions))

        REGIONS.merge(additional_regions).except(*disabled_regions)
      end

      def self.regions_by_hostname
        regions.values.index_by { |v| v[:hostname] }
      end

      def self.all
        regions.values
      end

      def self.names
        regions.keys
      end

      def self.hostnames
        regions_by_hostname.keys
      end

      def self.find_by_name(name)
        regions[name]
      end

      def self.find_by_hostname(hostname)
        regions_by_hostname[hostname]
      end
    end
  end
end
