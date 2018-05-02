# frozen_string_literal: true

# NOTE: use 'aws:extract:regions' rake task to renew the list

require 'yaml'

module ManageIQ
  module Providers::Amazon
    module Regions
      REGIONS = YAML.load_file(
        ManageIQ::Providers::Amazon::Engine.root.join('db/fixtures/aws_regions.yml')
      ).each_value(&:freeze).freeze

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
