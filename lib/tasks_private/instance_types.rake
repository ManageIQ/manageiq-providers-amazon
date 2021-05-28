namespace 'aws:extract' do
  desc 'Get / renew instance_types'
  task :instance_types do
    # Instance Types provided by the AWS SDK do not have sufficient info for provisioning
    #
    # This task creates a db/fixtures/aws_instance_types.yml file with data from
    #  https://raw.githubusercontent.com/powdahound/ec2instances.info/master/www/instances.json
    #
    # Other useful resources
    #   http://aws.amazon.com/ec2/instance-types
    #   http://docs.amazonwebservices.com/AWSEC2/latest/UserGuide/instance-types.html
    #   http://aws.amazon.com/ec2/previous-generation
    #   http://www.ec2instances.info/
    #   http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/t2-instances.html
    #   http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/c4-instances.html

    def instances
      require 'open-uri'
      URI.open("https://raw.githubusercontent.com/powdahound/ec2instances.info/master/www/instances.json") do |io|
        JSON.parse(io.read)
      end
    end

    results = instances.map do |instance|
      storage             = instance["storage"] || {}
      num_storage_devices = storage["devices"].to_i
      storage_size        = storage["size"].to_f

      ebs_only = instance["storage"].nil?

      storage_type = if storage["nvme_ssd"]
                       "NVMe SSD"
                     elsif storage["ssd"]
                       "SSD"
                     end

      network_performance = if instance["network_performance"].match?(/(\d+ Gigabit)/)
                              :very_high
                            else
                              instance["network_performance"].downcase.tr(' ', '_').to_sym
                            end

      result = {
        :architecture            => instance["arch"].map(&:to_sym).sort,
        :cluster_networking      => nil,
        :current_generation      => instance["generation"] != "previous",
        :current_version         => true,
        :description             => instance["pretty_name"],
        :ebs_only                => ebs_only,
        :ebs_optimized_available => instance["ebs_optimized"],
        :enhanced_networking     => instance["enhanced_networking"],
        :family                  => instance["family"],
        :instance_store_size     => (num_storage_devices * storage_size).gigabyte.to_i,
        :instance_store_size_gb  => num_storage_devices * storage_size,
        :instance_store_type     => storage_type,
        :instance_store_volumes  => num_storage_devices,
        :intel_aes_ni            => true,
        :intel_avx               => instance["intel_avx"],
        :intel_avx2              => instance["intel_avx2"],
        :intel_turbo             => instance["intel_turbo"],
        :memory                  => instance["memory"].gigabyte.to_i,
        :memory_gb               => instance["memory"],
        :name                    => instance["instance_type"],
        :network_performance     => network_performance,
        :physical_processor      => instance["physical_processor"].chomp('*'),
        :processor_clock_speed   => instance["clock_speed_ghz"],
        :vcpu                    => instance["vCPU"],
        :virtualization_type     => instance["linux_virtualization_types"].map(&:downcase).map(&:to_sym).sort.map { |v| v == :pv ? :paravirtual : v },
        :vpc_only                => instance["vpc_only"]
      }

      # this key is only present if the instance is deprecated
      result[:deprecated] = true if instance["generation"] == "previous"

      [result[:name], result.sort.to_h]
    end.sort.to_h

    File.write(ManageIQ::Providers::Amazon::Engine.root.join("db/fixtures/aws_instance_types.yml"), results.to_yaml)
  end
end
