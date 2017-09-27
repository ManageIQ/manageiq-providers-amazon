desc "Create new instance_types.rb"
task :instance_types => [:environment] do
  # Instance Types are not provided by the AWS SDK
  #
  # This task creates a instance_types.rb file in the current directory based upon the current
  # instance_types.rb file and data from
  #  curl https://raw.githubusercontent.com/powdahound/ec2instances.info/master/www/instances.json > lib/tasks_private/instance_types_data/instances.json
  #
  # Other useful resources
  #   http://aws.amazon.com/ec2/instance-types
  #   http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/instance-types.html
  #   http://aws.amazon.com/ec2/previous-generation
  #   http://www.ec2instances.info/
  #   http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/t2-instances.html
  #   http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/c4-instances.html
  require 'csv'
  require 'open-uri'

  def format_instance(instance)
    <<-EOT
    "#{instance[:name]}"#{' ' * (12 - instance[:name].length)}=> {#{instance[:name] == 't2.micro' ? "\n      :default                 => true," : ''}#{instance[:disabled] ? "\n      :disabled                => true," : ''}
      :name                    => "#{instance[:name]}",
      :family                  => "#{instance[:family]}",
      :description             => "#{instance[:description]}",
      :memory                  => #{instance[:memory] / Numeric::GIGABYTE}.gigabytes,
      :vcpu                    => #{instance[:vcpu]},
      :ebs_only                => #{instance[:ebs_only]},
      :instance_store_size     => #{instance[:instance_store_size] > 0 ? (instance[:instance_store_size] / Numeric::GIGABYTE).to_s + '.gigabytes' : 0},
      :instance_store_volumes  => #{instance[:instance_store_volumes]},#{instance[:instance_store_ssd] ? ' # SSD' : ''}
      :architecture            => #{instance[:architecture]},
      :virtualization_type     => #{instance[:virtualization_type]},
      :network_performance     => :#{instance[:network_performance]},
      :physical_processor      => "#{instance[:physical_processor]}",
      :processor_clock_speed   => "#{instance[:processor_clock_speed]}",
      :intel_aes_ni            => #{instance[:intel_aes_ni] ? 'true' : 'nil'},
      :intel_avx               => #{instance[:intel_avx] ? 'true' : 'nil'},
      :intel_avx2              => #{instance[:intel_avx2] ? 'true' : 'nil'},
      :intel_turbo             => #{instance[:intel_turbo] ? 'true' : 'nil'},
      :ebs_optimized_available => #{instance[:ebs_optimized_available] ? 'true' : 'nil'},
      :enhanced_networking     => #{instance[:enhanced_networking] ? 'true' : 'nil'},
      :cluster_networking      => #{instance[:cluster_networking]  ? 'true' : 'nil'},
      :vpc_only                => #{instance[:vpc_only]},
    },
    EOT
  end

  def cluster_networking?(type)
    # https://aws.amazon.com/ec2/instance-types/#Cluster_Networking
    type.split('.').first.in?(%w(r4 x1 m4 c4 c3 i2 cr1 g2 hs1 p2 d2))
  end

  def format_instance_miq(i)
    {}.tap do |o|
      # x1.16large manually fixed to x1.16xlarge
      # i3.16large manually fixed to i3.16xlarge
      %i(family instance_store_size instance_store_volumes vpc_only enhanced_networking).each do |key|
        o[key] = i[key]
      end
      o[:memory] = i[:memory].to_f.gigabyte
      o[:name] = i[:instance_type]
      o[:description] = i[:pretty_name]
      o[:vcpu] = i[:vCPU]
      o[:ebs_optimized_available] = i[:ebs_optimized]
      o[:instance_store_volumes] = i.fetch_path(:storage, :devices).to_i
      o[:instance_store_size] = (o[:instance_store_volumes] * i.fetch_path(:storage, :size).to_f).gigabyte
      o[:instance_store_ssd] = i.fetch_path(:storage, :ssd)
      o[:architecture] = i[:arch].map(&:to_sym).sort
      o[:virtualization_type] = i[:linux_virtualization_types].map(&:downcase).map(&:to_sym).sort.map { |v| v == :pv ? :paravirtual : v }
      o[:network_performance] =
        case i[:network_performance]
        when '10 Gigabit', '20 Gigabit', '25 Gigabit'
          :very_high
        when ''
          :unknown
        else
          i[:network_performance].downcase.tr(' ', '_').to_sym
        end
      o[:ebs_only] = i[:storage].nil? # see https://github.com/ManageIQ/manageiq/issues/741#issuecomment-57353290
      o[:physical_processor] = i[:physical_processor].nil? ? '' : i[:physical_processor].chomp('*')
      o[:processor_clock_speed] = i[:clock_speed_ghz]
      o[:intel_aes_ni] = true # looks like only deprecated types dont support it, so we assume all new types support it
      #  https://aws.amazon.com/ec2/instance-types/#intel
      o[:intel_avx] = i[:intel_avx]
      o[:intel_avx2] = i[:intel_avx2]
      o[:intel_turbo] = i[:intel_turbo]
      o[:cluster_networking] = cluster_networking?(i[:instance_type])
    end
  end

  available = {}
  previous = {}
  instances = YAML.safe_load(File.open(File.join(__dir__, 'instance_types_data/instances.json')).read)
  instances.each do |i|
    i.deep_symbolize_keys!
    miq_format = format_instance_miq(i)
    if i[:generation] == 'current'
      available[i[:instance_type]] = miq_format
    else
      previous[i[:instance_type]] = miq_format
    end
  end

  new_instance_types_file = ''
  instance_types_file_enum = open(ManageIQ::Providers::Amazon::Engine.root.join('app/models/manageiq/providers/amazon/instance_types.rb')).each_line
  instance_types_file_enum.each do |line|
    new_instance_types_file << line
    break if line =~ /AVAILABLE_TYPES/
  end

  # current available types
  current_available = ManageIQ::Providers::Amazon::InstanceTypes::AVAILABLE_TYPES.dup
  output_instances = []
  current_available.keys.each do |type|
    available_instance = available[type]
    next unless available_instance
    output_instances << available_instance
    current_available.delete(type)
    available.delete(type)
  end

  # new available types
  new_count = available.count
  available.values.each do |instance|
    output_instances << instance
  end

  new_instance_types_file << output_instances.map { |i| format_instance(i) }.join("\n")
  new_instance_types_file << <<EOT
  }.freeze

  # Types that are still advertised, but not recommended for new instances.
  DEPRECATED_TYPES = {
EOT

  # current deprecated types
  output_instances = []
  current_deprecated = ManageIQ::Providers::Amazon::InstanceTypes::DEPRECATED_TYPES.dup
  current_deprecated.each do |type, instance|
    next unless previous.key?(type)
    output_instances << instance
    current_deprecated.delete(type)
    previous.delete(type)
  end

  # new deprecated types
  deprecated_count = current_available.count
  current_available.each do |type, instance|
    next unless previous.key?(type)
    output_instances << instance
    current_available.delete(type)
    previous.delete(type)
  end

  raise "#{previous.keys} are deprecated but have not been current before!" if previous.any?

  new_instance_types_file << output_instances.map { |i| format_instance(i) }.join("\n")
  new_instance_types_file << <<EOT
  }.freeze

  # Types that are no longer advertised
  DISCONTINUED_TYPES = {
EOT
  # current discontinued types
  output_instances = []
  current_discontinued = ManageIQ::Providers::Amazon::InstanceTypes::DISCONTINUED_TYPES.dup
  current_discontinued.values.each do |instance|
    instance[:disabled] = true
    output_instances << instance
  end

  # new discontinued from current_available
  discontinued_count = current_available.count
  current_available.values.each do |instance|
    instance[:disabled] = true
    output_instances << instance
  end

  # new discontinued from current_deprecated
  discontinued_count += current_deprecated.count
  current_deprecated.values.each do |instance|
    instance[:disabled] = true
    output_instances << instance
  end

  new_instance_types_file << output_instances.map { |i| format_instance(i) }.join("\n")
  new_instance_types_file << <<EOT
  }.freeze

  def self.instance_types
    additional = Hash(Settings.ems.ems_amazon.try!(:additional_instance_types)).stringify_keys
    disabled = Array(Settings.ems.ems_amazon.try!(:disabled_instance_types))
    AVAILABLE_TYPES.merge(DEPRECATED_TYPES).merge(DISCONTINUED_TYPES).merge(additional).except(*disabled)
  end

  def self.all
    instance_types.values
  end

  def self.names
    instance_types.keys
  end
end
EOT

  File.open(ManageIQ::Providers::Amazon::Engine.root.join('instance_types.rb'), 'w') do |f|
    f.puts(new_instance_types_file)
  end

  puts <<EOT
Created ./instance_types.rb with #{new_count} new, #{deprecated_count} newly deprecated and #{discontinued_count} new discontinued instances.
Now copy it to the existing one:

mv instance_types.rb app/models/manageiq/providers/amazon/instance_types.rb
EOT
end
