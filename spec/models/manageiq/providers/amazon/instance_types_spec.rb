describe ManageIQ::Providers::Amazon::InstanceTypes do
  require 'CSV'

  def format_instance(instance)
    <<-EOT
    "#{instance[:name]}"#{' ' * (12 - instance[:name].length)}=> {
      :name                    => "#{instance[:name]}",
      :family                  => "#{instance[:family]}",
      :description             => "#{instance[:description]}",
      :memory                  => #{instance[:memory] / Numeric::GIGABYTE}.gigabytes,
      :vcpu                    => #{instance[:vcpu]},
      :ebs_only                => #{instance[:ebs_only]},
      :instance_store_size     => #{instance[:instance_store_size] > 0 ? (instance[:instance_store_size] / Numeric::GIGABYTE).to_s + '.gigabytes' : 0},
      :instance_store_volumes  => #{instance[:instance_store_volumes]},
      :architecture            => #{instance[:architecture]},
      :virtualization_type     => #{instance[:virtualization_type]},
      :network_performance     => :#{instance[:network_performance]},
      :physical_processor      => "#{instance[:physical_processor]}",
      :processor_clock_speed   => #{instance[:processor_clock_speed]},
      :intel_aes_ni            => #{instance[:intel_aes_ni]},
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
    type.split('.').first.in? %w(r4 x1 m4 c4 c3 i2 cr1 g2 hs1 p2 d2)
  end

  it "is the same" do
    require 'open-uri'

    VCR.use_cassette(described_class.name.underscore) do
      instances = YAML.safe_load(open('https://raw.githubusercontent.com/powdahound/ec2instances.info/master/www/instances.json').read)
      ec2instances = instances.each_with_object({}) do |i, h|
        i.deep_symbolize_keys!
        h[i[:instance_type]] = i
      end

      # from https://aws.amazon.com/ec2/instance-types/#instance-type-matrix
      # converted to csv via http://www.convertcsv.com/html-table-to-csv.htm
      available = {}
      CSV.foreach(File.join(File.dirname(__FILE__), "instance_types.csv"), :headers => true, :header_converters => :symbol) do |row|
        i = ec2instances[row[:instance_type]]
        o = {}
        # x1.16large manually fixed to x1.16xlarge
        # i3.16large manually fixed to i3.16xlarge
        raise "no current instance #{row[:instance_type]} at ec2instances" unless i
        %i(family instance_store_size instance_store_volumes vpc_only).each do |key|
          o[key] = i[key]
        end
        o[:memory] = i[:memory].to_f.gigabyte
        o[:name] = i[:instance_type]
        o[:description] = i[:pretty_name]
        o[:vcpu] = i[:vCPU]
        o[:ebs_optimized_available] = i[:ebs_optimized] == 'true'
        o[:instance_store_volumes] = i.fetch_path(:storage, :devices).to_i
        o[:instance_store_size] = (o[:instance_store_volumes] * i.fetch_path(:storage, :size).to_f).gigabyte
        o[:architecture] = i[:arch].map(&:to_sym).sort
        o[:virtualization_type] = i[:linux_virtualization_types].map(&:downcase).map(&:to_sym).sort
        o[:network_performance] = case i[:network_performance]
          when '10 Gigabit', '20 Gigabit'
            :very_high
          else
            i[:network_performance].downcase.tr(' ','_').to_sym
        end
        # see https://github.com/ManageIQ/manageiq/issues/741#issuecomment-57353290
        #o[:ebs_only] = i[:instance_store_volumes] == 0 && i[:instance_store_size] == 0

        # we take ebs_only from `instance_types.csv`
        o[:ebs_only] = row[:storage_gb] == 'EBS Only'
        o[:physical_processor] = row[:physical_processor]
        o[:processor_clock_speed] = row[:clock_speed_ghz].scan(/[\d\.]/).join
        o[:intel_aes_ni] = true # looks like only deprecated types dont support it, so we assume all new types support it
        #  https://aws.amazon.com/ec2/instance-types/#intel
        o[:intel_avx] = row[:intel_avx] == 'Yes'
        o[:intel_avx2] = row[:intel_avx2] == 'Yes'
        o[:intel_turbo] = row[:intel_turbo] == 'Yes'


        o[:cluster_networking] = cluster_networking?(row[:instance_type])
        available[row[:instance_type]] = o
      end


      # from https://aws.amazon.com/ec2/previous-generation/#Previous_Generation_Instance_Details_and_Pricing_
      # converted to csv via http://www.convertcsv.com/html-table-to-csv.htm
      discontinued = {}
      CSV.foreach(File.join(File.dirname(__FILE__), "instance_types_previous.csv"), :headers => true, :header_converters => :symbol) do |row|
        # i = ec2instances[row[:instance_type]]
        # current = described_class::DEPRECATED_TYPES[row[:instance_type]] || described_class::AVAILABLE_TYPES[row[:instance_type]]
        # raise "no previous #{row[:instance_type]} at DEPRECATED_TYPES or AVAILABLE_TYPES" unless current
        # raise "no previous #{row[:instance_type]} at ec2instances" unless i
        # i[:physical_processor] = row[:physical_processor]
        # i[:processor_clock_speed] = current[:processor_clock_speed]
        # i[:avx] = current[:intel_avx]
        # i[:avx2] = current[:intel_avx2]
        # i[:turbo] = current[:intel_turbo]
        # i[:cluster_networking] = cluster_networking?(row[:instance_type])
        discontinued[row[:instance_type]] = row
        # puts format_instance(i)
      end



      new_instance_types_file = ''
      instance_types_file_enum = open(ManageIQ::Providers::Amazon::Engine.root.join('app/models/manageiq/providers/amazon/instance_types.rb')).each_line
      instance_types_file_enum.each do |line|
        new_instance_types_file << line
        break if line =~ /AVAILABLE_TYPES/
      end

      # Output current available types
      current_available = described_class::AVAILABLE_TYPES.dup
      current_available.keys.each do |type|
        available_instance = available[type]
        if available_instance
          new_instance_types_file << format_instance(available_instance)
          current_available.delete(type)
        end
      end

      # instance_types_file_enum.each do |line|
      #   next unless line =~ /# Types that are still advertised/
      # end

      new_instance_types_file << <<EOT
  }

  # Types that are still advertised, but not recommended for new instances.
  DEPRECATED_TYPES = {
EOT

      # Output current deprecated types
      current_deprecated = described_class::DEPRECATED_TYPES.dup
      current_deprecated.each do |type, instance|
        if discontinued.has_key?(type)
          new_instance_types_file << format_instance(instance)
          current_deprecated.delete(type)
        end
      end

      # newly deprecated types
      current_available.each do |type, instance|
        if discontinued.has_key?(type)
          new_instance_types_file << format_instance(instance)
          current_available.delete(type)
        end
      end

      # current discontinued types
      File.open('/tmp/instance_types.rb', 'w') do |f|
        f.puts(new_instance_types_file)
      end

    end
  end

end
