# frozen_string_literal: true

class AwsInstanceDataParser
  REQUIRED_ATTRIBUTES = %w(
    currentVersion
    currentGeneration
    clockSpeed
    dedicatedEbsThroughput
    ebsOptimized
    enhancedNetworkingSupported
    instanceFamily
    instanceType
    intelAvx2Available
    intelAvxAvailable
    intelTurboAvailable
    memory
    networkPerformance
    physicalProcessor
    processorArchitecture
    processorFeatures
    storage
    vcpu
  ).freeze

  TYPE_REGEXP    = /^(?:(.*)\.)?(\d+)?(.*)/
  MEMORY_REGEXP  = /^\s*((?:\d+,?)+\.?\d*)\s+GiB\s*$/i
  STORAGE_REGEXP = /^(?:(\d+)\s+x\s+)((?:\d+[.,])?\d+)(?:\s+(.+))?$/
  NETWORK_REGEXP = /^\d+\sGigabit$/i

  INTEL_AVX_REGEXP   = /\bIntel AVX\b/
  INTEL_AVX2_REGEXP  = /\bIntel AVX2\b/
  INTEL_TURBO_REGEXP = /\bIntel Turbo\b/

  CPU_ARCHES = {
    '32-bit or 64-bit' => %i(i386 x86_64).freeze,
    '64-bit'           => %i(x86_64).freeze,
  }.freeze

  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/
  #   virtualization_types.html
  VIRT_TYPES = Hash.new(%i(hvm).freeze).tap do |virt_types|
    {
      %w(t1 m1 m2 c1)   => %i(paravirtual).freeze,
      %w(m3 c3 hs1 hi1) => %i(paravirtual hvm).freeze,
    }.each do |type_names, types_set|
      type_names.each { |type_name| virt_types[type_name] = types_set }
    end
  end.freeze

  # for :description
  POPULAR_TYPES = %w(t1 t2).freeze

  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/
  #   using-vpc.html#vpc-only-instance-types
  VPC_ONLY_TYPES = %w(m4 m5 t2 c4 c5 r4 x1 h1 i3 f1 g3 p2 p3).freeze

  # https://github.com/ManageIQ/manageiq-providers-amazon/
  #   blob/933a3d08e0adb012c7cbefbaeaa262a81c855fe1/
  #   lib/tasks_private/instance_types.rake#L49
  CLUSTERABLE_TYPES = %w(m4 c3 c4 cr1 r4 x1 hs1 i2 g2 p2 d2).freeze

  # some types data missing this
  EBS_OPTIMIZED_TYPES = %w(x1).freeze

  # some types data missing 'intel' features info
  CPU_FEATURES = {
    'Intel Xeon E5-2670'                              => %i(avx turbo).freeze,
    'Intel Xeon E5-2670 v2 (Ivy Bridge/Sandy Bridge)' => %i(avx turbo).freeze,
    'Intel Xeon E5-2666 v3 (Haswell)'                 => %i(avx avx2 turbo).freeze,
    'Intel Xeon E5-2686 v4 (Broadwell)'               => %i(avx avx2 turbo).freeze,
  }.freeze

  # considering all types have it except of legacy ones
  NON_AES_NI_TYPES = %w(t1 m1).freeze

  # some types data missing this (here is only those who missing)
  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/
  #   enhanced-networking.html#supported_instances
  ENHANCED_NETWORKING_TYPES = %w(f1).freeze

  ParsedName = Struct.new(:base_type, :size_factor, :size_name)
  ParsedStorage = Struct.new(:volumes, :size, :type)

  private_constant(*constants(false).without(:REQUIRED_ATTRIBUTES))

  attr_reader :product_data

  def initialize(product_data)
    @parsed = false
    @product_data = product_data
    @unknown_values = {}
  end

  def result
    [instance_data, unknown_values]
  end

  def instance_data
    parse! unless @parsed
    @instance_data
  end

  def unknown_values
    parse! unless @parsed
    @unknown_values
  end

  ### individual attributes

  ## general

  def current_generation?
    product_data['currentGeneration'] == 'Yes'
  end

  def current_version?
    !!product_data['currentVersion']
  end

  def instance_type
    product_data['instanceType']
  end

  def instance_family
    product_data['instanceFamily']
  end

  delegate :base_type, :to => :parsed_name

  def description
    description = [base_type.to_s.upcase]
    description << instance_family unless POPULAR_TYPES.include?(base_type)
    description << (size_name == 'xlarge' ? "#{size_factor}XL" : size_name.capitalize)
    description.join(' ')
  end

  ## virtualization

  def virtualization_type
    VIRT_TYPES[base_type]
  end

  delegate :size_factor, :size_name, :to => :parsed_name

  def vcpus
    product_data['vcpu'].to_i
  end

  ## cpu

  def physical_processor
    product_data['physicalProcessor']
  end

  def cpu_clock_speed
    product_data['clockSpeed']
  end

  def cpu_arches
    CPU_ARCHES.fetch(product_data['processorArchitecture']) do |cpu_arch|
      save_unknown(cpu_arch)
    end
  end

  def processor_features
    product_data['processorFeatures']
  end

  def intel_avx?
    product_data['intelAvxAvailable'] == 'Yes' ||
      !!(processor_features =~ INTEL_AVX_REGEXP) ||
      CPU_FEATURES[physical_processor]&.include?(:avx)
  end

  def intel_avx2?
    product_data['intelAvx2Available'] == 'Yes' ||
      !!(processor_features =~ INTEL_AVX2_REGEXP) ||
      CPU_FEATURES[physical_processor]&.include?(:avx2)
  end

  def intel_turbo?
    product_data['intelTurboAvailable'] == 'Yes' ||
      !!(processor_features =~ INTEL_TURBO_REGEXP) ||
      CPU_FEATURES[physical_processor]&.include?(:turbo)
  end

  def intel_aes_ni?
    NON_AES_NI_TYPES.exclude?(base_type)
  end

  ## memory

  def memory
    @memory ||= begin
      memory = product_data['memory']
      (MEMORY_REGEXP.match(memory)&.captures&.first || save_unknown(memory)).to_s.tr(',', '').to_f
    end
  end

  ## storage

  def storage
    product_data['storage']
  end

  def ebs_only?
    storage == 'EBS only'
  end

  def ebs_optimized?
    product_data['ebsOptimized'] == 'Yes' ||
      product_data['dedicatedEbsThroughput'].present? ||
      EBS_OPTIMIZED_TYPES.include?(base_type)
  end

  def storage_volumes
    parsed_storage.volumes
  end

  def storage_size
    parsed_storage.size
  end

  def storage_type
    parsed_storage.type
  end

  ## network

  def network_performance
    net_perf = product_data['networkPerformance']
    net_perf =~ NETWORK_REGEXP ? :very_high : net_perf.downcase.gsub(/\s/, '_').to_sym
  end

  def enhanced_networking?
    product_data['enhancedNetworkingSupported'] == 'Yes' ||
      ENHANCED_NETWORKING_TYPES.include?(base_type)
  end

  def clusterable_networking?
    CLUSTERABLE_TYPES.include?(base_type)
  end

  def vpc_only?
    VPC_ONLY_TYPES.include?(base_type)
  end

  private

  def parse!
    @instance_data = {
      :current_generation      => current_generation?,
      :current_version         => current_version?,
      :name                    => instance_type,
      :family                  => instance_family,
      :description             => description,
      :memory                  => memory.gigabytes.to_i,
      :memory_gb               => memory,
      :vcpu                    => vcpus,
      :ebs_only                => ebs_only?,
      :instance_store_size     => storage_size.gigabyte.to_i,
      :instance_store_size_gb  => storage_size,
      :instance_store_volumes  => storage_volumes,
      :instance_store_type     => storage_type,
      :architecture            => cpu_arches,
      :virtualization_type     => virtualization_type,
      :network_performance     => network_performance,
      :physical_processor      => physical_processor,
      :processor_clock_speed   => cpu_clock_speed,
      :intel_aes_ni            => intel_aes_ni?           || nil,
      :intel_avx               => intel_avx?              || nil,
      :intel_avx2              => intel_avx2?             || nil,
      :intel_turbo             => intel_turbo?            || nil,
      :ebs_optimized_available => ebs_optimized?          || nil,
      :enhanced_networking     => enhanced_networking?    || nil,
      :cluster_networking      => clusterable_networking? || nil,
      :vpc_only                => vpc_only?,
    }.freeze
    @unknown_values.freeze
    @parsed = true
  end

  def save_unknown(value, attribute_name = nil, nils: nil)
    attribute_name ||= caller_locations(1..1).first.label # use a bit of magic
    (@unknown_values[attribute_name.to_sym] ||= Set.new) << value
    nils ? Array.new(nils, nil) : nil
  end

  ### compound attributes

  def parsed_name
    @parsed_name ||=
      ParsedName.new(
        *(
          TYPE_REGEXP.match(instance_type)&.captures ||
          save_unknown(instance_type, :instance_type, :nils => 3)
        )
      ).freeze
  end

  def parsed_storage
    @parsed_storage ||= begin
      volumes, size, type =
        if ebs_only?
          Array.new(3, nil)
        else
          STORAGE_REGEXP.match(storage)&.captures ||
            save_unknown(storage, :storage, :nils => 3)
        end
      volumes = volumes.to_i
      type = type&.gsub(/\bGB\b/i, '').presence
      size = size&.gsub(/\D/, '').to_f * volumes
      ParsedStorage.new(volumes, size, type)
    end
  end
end
