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
    special_regions = Set.new

    response = Net::HTTP.get_response(uri)
    data = JSON.parse(response.body)

    regions = data['partitions'].each_with_object({}) do |partition, memo|
      dns_suffix = partition['dnsSuffix']
      regions_info = partition['regions']
      default_partition = partition['partition'] == default_partition_name

      partition['services'][service_name]['endpoints'].each_key do |region_name|
        raise "Repetitive region name: #{region_name}" if memo.key?(region_name)

        memo[region_name] = {
          :name        => region_name,
          :hostname    => "#{service_name}.#{region_name}.#{dns_suffix}",
          :description => regions_info.fetch(region_name).fetch('description'),
        }.freeze

        special_regions << region_name unless default_partition
      end
    end

    settings_file = engine_root.join('config/settings.yml')
    setting_lines = settings_file.readlines # can't just read & dump YAML keeping it's comments

    line_index  = setting_lines.index { |line| line =~ /\s*:disabled_regions:\s*/ }
    indentation = setting_lines[line_index] =~ /\S/

    delete_index = line_index + 1
    loop do
      break if delete_index >= setting_lines.size

      line = setting_lines[delete_index]
      indent = (line =~ /\S/).to_i
      strip_line = line.strip

      if strip_line.empty? || strip_line.start_with?('#')
        delete_index += 1
        next
      end

      break if indent < indentation || indent == indentation && !strip_line.start_with?('-')

      setting_lines.delete_at(delete_index)
    end

    setting_lines[line_index] = "#{' ' * indentation}:disabled_regions:\n"
    line_index  += 1
    indentation += 2

    special_regions.to_a.to_yaml.each_line.to_a[1..-1].reverse_each do |line|
      setting_lines.insert(line_index, "#{' ' * indentation}#{line}")
    end

    settings_file.write(setting_lines.join)

    out_file.write(regions.to_yaml)
  end
end
