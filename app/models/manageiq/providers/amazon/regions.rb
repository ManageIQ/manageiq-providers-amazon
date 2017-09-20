# The aws-sdk gem can get us this information, however it talks to EC2 to get it.
# For cases where we don't yet want to contact EC2, this information is hardcoded.

module ManageIQ
  module Providers::Amazon
    module Regions
      # From http://docs.aws.amazon.com/general/latest/gr/rande.html#ec2_region
      REGIONS = {
        "us-east-1"      => {
          :name        => "us-east-1",
          :hostname    => "ec2.us-east-1.amazonaws.com",
          :description => "US East (Northern Virginia)",
        },
        "us-east-2"      => {
          :name        => "us-east-2",
          :hostname    => "ec2.us-east-2.amazonaws.com",
          :description => "US East (Ohio)",
        },
        "us-west-1"      => {
          :name        => "us-west-1",
          :hostname    => "ec2.us-west-1.amazonaws.com",
          :description => "US West (Northern California)",
        },
        "us-west-2"      => {
          :name        => "us-west-2",
          :hostname    => "ec2.us-west-2.amazonaws.com",
          :description => "US West (Oregon)",
        },
        "eu-west-1"      => {
          :name        => "eu-west-1",
          :hostname    => "ec2.eu-west-1.amazonaws.com",
          :description => "EU (Ireland)",
        },
        "eu-west-2"      => {
          :name        => "eu-west-2",
          :hostname    => "ec2.eu-west-2.amazonaws.com",
          :description => "EU (London)",
        },
        "eu-central-1"   => {
          :name        => "eu-central-1",
          :hostname    => "ec2.eu-central-1.amazonaws.com",
          :description => "EU (Frankfurt)",
        },
        "ap-south-1"     => {
          :name        => "ap-south-1",
          :hostname    => "ec2.ap-south-1.amazonaws.com",
          :description => "Asia Pacific (Mumbai)",
        },
        "ap-southeast-1" => {
          :name        => "ap-southeast-1",
          :hostname    => "ec2.ap-southeast-1.amazonaws.com",
          :description => "Asia Pacific (Singapore)",
        },
        "ap-southeast-2" => {
          :name        => "ap-southeast-2",
          :hostname    => "ec2.ap-southeast-2.amazonaws.com",
          :description => "Asia Pacific (Sydney)",
        },
        "ap-northeast-1" => {
          :name        => "ap-northeast-1",
          :hostname    => "ec2.ap-northeast-1.amazonaws.com",
          :description => "Asia Pacific (Tokyo)",
        },
        "ca-central-1"   => {
          :name        => "ca-central-1",
          :hostname    => "ec2.ca-central-1.amazonaws.com",
          :description => "Canada (Central)",
        },
        "ap-northeast-2" => {
          :name        => "ap-northeast-2",
          :hostname    => "ec2.ap-northeast-2.amazonaws.com",
          :description => "Asia Pacific (Seoul)",
        },
        "sa-east-1"      => {
          :name        => "sa-east-1",
          :hostname    => "ec2.sa-east-1.amazonaws.com",
          :description => "South America (Sao Paulo)",
        },
        "us-gov-west-1"  => {
          :name        => "us-gov-west-1",
          :hostname    => "ec2.us-gov-west-1.amazonaws.com",
          :description => "GovCloud (US)",
        }
      }

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

      # TODO (Julian) allow default region to be changed by config.
      def self.default
        regions['us-east-1']
      end
    end
  end
end
