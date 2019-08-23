# frozen_string_literal: true

namespace 'aws:extract' do
  desc 'Get / renew regions list from online source of AWS gem'
  task :regions do
    require 'uri'
    require 'set'
    require 'json'
    require 'yaml'
    require 'net/http'

    engine_root = ManageIQ::Providers::Amazon::Engine.root

    # path valid for aws-sdk v3 gem's source
    uri = URI('https://raw.githubusercontent.com/aws/aws-sdk-ruby/master/gems/aws-partitions/partitions.json')
    out_file = engine_root.join('db/fixtures/aws_regions.yml')
    service_name = 'ec2'

    default_partition_name = 'aws'

    response = Net::HTTP.get_response(uri)
    data = JSON.parse(response.body)

    regions = data['partitions'].each_with_object({}) do |partition, memo|
      dns_suffix = partition['dnsSuffix']
      regions_info = partition['regions']

      partition['services'][service_name]['endpoints'].each_key do |region_name|
        raise "Repetitive region name: #{region_name}" if memo.key?(region_name)

        memo[region_name] = {
          :name        => region_name,
          :hostname    => "#{service_name}.#{region_name}.#{dns_suffix}",
          :description => regions_info.fetch(region_name).fetch('description'),
        }.freeze
      end
    end

    out_file.write(regions.to_yaml)
  end
end
