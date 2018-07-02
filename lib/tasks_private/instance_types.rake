# frozen_string_literal: true

# Interim code to demonstrate process of moving existing data from module to yaml

namespace 'aws:extract' do
  desc 'Unload instance types and details list from instance_types.rb file'
  task :instance_types do
    base_dir = ManageIQ::Providers::Amazon::Engine.root

    require base_dir.join('app/models/manageiq/providers/amazon/instance_types')

    out_file = base_dir.join('db/fixtures/aws_instance_types.yml')

    out_data = ManageIQ::Providers::Amazon::InstanceTypes::AVAILABLE_TYPES.dup

    data = ManageIQ::Providers::Amazon::InstanceTypes::DEPRECATED_TYPES.dup
    data.each_value { |v| v[:deprecated] = true }
    out_data.merge!(data) { |instance_type, _, _| puts "Duplicated #{instance_type} in DEPRECATED!" }

    data = ManageIQ::Providers::Amazon::InstanceTypes::DISCONTINUED_TYPES.dup
    data.each_value { |v| v[:discontinued] = true }
    out_data.merge!(data) { |instance_type, _, _| puts "Duplicated #{instance_type} in DISCONTINUED!" }

    out_file.write(out_data.deep_dup.to_yaml.each_line.map(&:rstrip).join("\n") << "\n")
  end
end
