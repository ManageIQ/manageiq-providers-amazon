# TODO: Separate collection from parsing (perhaps collecting in parallel a la RHEVM)

class ManageIQ::Providers::Amazon::CloudManager::RefreshParserDto < ManageIQ::Providers::CloudManager::RefreshParserDto
  include ManageIQ::Providers::Amazon::RefreshHelperMethods

  def initialize(ems, options = Config::Options.new)
    super

    @aws_ec2             = ems.connect
    @aws_cloud_formation = ems.connect(:service => :CloudFormation)
    @known_flavors       = Set.new

    initialize_dto_collections
  end

  def initialize_dto_collections
    add_dto_collection(ManageIQ::Providers::Amazon::CloudManager::Vm,
                       :vms)
    add_dto_collection(ManageIQ::Providers::Amazon::CloudManager::Template,
                       :miq_templates)
    add_dto_collection(Hardware,
                       :hardwares,
                       [:vm_or_template])
    add_dto_collection(Network,
                       :networks,
                       [:hardware, :description])
    add_dto_collection(Disk,
                       :disks,
                       [:hardware, :device_name])
    add_dto_collection(ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack,
                       :orchestration_stacks)
    add_dto_collection(ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone,
                       :availability_zones)
    add_dto_collection(ManageIQ::Providers::Amazon::CloudManager::Flavor,
                       :flavors)
    add_dto_collection(ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack,
                       :orchestration_stacks)
    add_dto_collection(OrchestrationStackOutput,
                       :orchestration_stacks_outputs)
    add_dto_collection(OrchestrationStackParameter,
                       :orchestration_stacks_parameters)
    add_dto_collection(OrchestrationStackResource,
                       :orchestration_stacks_resources)
    add_dto_collection(ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair,
                       :key_pairs,
                       [:name])

    # TODO(lsmola) do refactoring, we shouldn't need this custom saving block
    orchestration_template_save_block = -> (_ems, dto_collection) do
      hashes = dto_collection.data.map(&:attributes)

      templates = OrchestrationTemplate.find_or_create_by_contents(hashes)
      dto_collection.data.zip(templates).each { |dto, template| dto.build_object(template) }
    end

    @data[:orchestration_templates] = ::ManagerRefresh::DtoCollection.new(
      OrchestrationTemplateCfn,
      :parent            => @ems,
      :association       => :orchestration_templates,
      :custom_save_block => orchestration_template_save_block)
  end

  def ems_inv_to_hashes
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{@ems.name}] id: [#{@ems.id}]"

    $aws_log.info("#{log_header}...")
    # The order of the below methods does matter, because there are inner dependencies of the data!
    get_flavors
    get_availability_zones
    get_key_pairs
    get_stacks
    get_private_images if @options.get_private_images
    get_shared_images  if @options.get_shared_images
    get_public_images  if @options.get_public_images
    get_instances
    $aws_log.info("#{log_header}...Complete")

    @data
  end

  private

  def get_flavors
    process_dto_collection(ManageIQ::Providers::Amazon::InstanceTypes.all, :flavors) { |flavor| parse_flavor(flavor) }
  end

  def get_availability_zones
    azs = @aws_ec2.client.describe_availability_zones[:availability_zones]
    process_dto_collection(azs, :availability_zones) { |az| parse_availability_zone(az) }
  end

  def get_key_pairs
    kps = @aws_ec2.client.describe_key_pairs[:key_pairs]
    process_dto_collection(kps, :key_pairs) { |kp| parse_key_pair(kp) }
  end

  def get_private_images
    get_images(
      @aws_ec2.client.describe_images(:owners  => [:self],
                                      :filters => [{:name   => "image-type",
                                                    :values => ["machine"]}])[:images])
  end

  def get_shared_images
    get_images(
      @aws_ec2.client.describe_images(:executable_users => [:self],
                                      :filters          => [{:name   => "image-type",
                                                             :values => ["machine"]}])[:images])
  end

  def get_public_images
    filters = @options.public_images_filters
    get_images(
      @aws_ec2.client.describe_images(:executable_users => [:all],
                                      :filters          => filters)[:images], true)
  end

  def get_images(images, is_public = false)
    process_dto_collection(images, :miq_templates) { |image| parse_image(image, is_public) }
  end

  def get_image_hardware(image)
    process_dto_collection([image], :hardwares) { |image| parse_image_hardware(image) }
  end

  def get_stacks
    stacks = @aws_cloud_formation.stacks
    process_dto_collection(stacks, :orchestration_stacks) { |stack| parse_stack(stack) }
  end

  def get_stack_parameters(stack)
    parameters = stack.parameters.each_with_object({}) { |sp, hash| hash[sp.parameter_key] = sp.parameter_value }

    process_dto_collection(parameters, :orchestration_stacks_parameters) do |param_key, param_val|
      parse_stack_parameter(param_key, param_val, stack.stack_id)
    end
  end

  def get_stack_outputs(stack)
    outputs = stack.outputs

    process_dto_collection(outputs, :orchestration_stacks_outputs) do |output|
      parse_stack_output(output, stack.stack_id)
    end
  end

  def get_stack_resources(stack)
    resources = stack.resource_summaries.entries

    # physical_resource_id can be empty if the resource was not successfully created; ignore such
    resources.reject! { |r| r.physical_resource_id.nil? }

    process_dto_collection(resources, :orchestration_stacks_resources) do |resource|
      parse_stack_resource(resource, stack.stack_id)
    end
  end

  def get_stack_template(stack)
    process_dto_collection([stack], :orchestration_templates) { |the_stack| parse_stack_template(the_stack) }
  end

  def get_instances
    instances = @aws_ec2.instances
    process_dto_collection(instances, :vms) { |instance| parse_instance(instance) }
  end

  def get_instance_hardware(instance, flavor)
    process_dto_collection([instance], :hardwares) { |instance| parse_instance_hardware(instance, flavor) }
  end

  def get_hardware_networks(instance)
    process_dto_collection([instance], :networks) { |instance| parse_hardware_private_network(instance) }
    process_dto_collection([instance], :networks) { |instance| parse_hardware_public_network(instance) }
  end

  def get_hardware_disks(instance, flavor)
    disks = []

    if flavor[:ephemeral_disk_count] > 0
      single_disk_size = flavor[:ephemeral_disk_size] / flavor[:ephemeral_disk_count]
      flavor[:ephemeral_disk_count].times do |i|
        add_instance_disk(disks, single_disk_size, i, "Disk #{i}")
      end
    end

    disks.each do |d|
      d[:hardware] = @data[:hardwares].lazy_find(instance.id)
    end

    process_dto_collection(disks, :disks) { |x| parse_disk(x) }
  end

  def parse_disk(x)
    # TODO(lsmola) remove the need for returning tuple, the id is not used
    return nil, x
  end

  def parse_flavor(flavor)
    name = uid = flavor[:name]

    cpus = flavor[:vcpu]

    new_result = {
      :type                     => ManageIQ::Providers::Amazon::CloudManager::Flavor.name,
      :ems_ref                  => uid,
      :name                     => name,
      :description              => flavor[:description],
      :enabled                  => !flavor[:disabled],
      :cpus                     => cpus,
      :cpu_cores                => 1,
      :memory                   => flavor[:memory],
      :supports_32_bit          => flavor[:architecture].include?(:i386),
      :supports_64_bit          => flavor[:architecture].include?(:x86_64),
      :supports_hvm             => flavor[:virtualization_type].include?(:hvm),
      :supports_paravirtual     => flavor[:virtualization_type].include?(:paravirtual),
      :block_storage_based_only => flavor[:ebs_only],
      :cloud_subnet_required    => flavor[:vpc_only],
      :ephemeral_disk_size      => flavor[:instance_store_size],
      :ephemeral_disk_count     => flavor[:instance_store_volumes]
    }

    return uid, new_result
  end

  def parse_availability_zone(az)
    name = uid = az.zone_name

    # power_state = (az.state == :available) ? "on" : "off",

    new_result = {
      :type    => ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.name,
      :ems_ref => uid,
      :name    => name,
    }

    return uid, new_result
  end

  def parse_key_pair(kp)
    name = uid = kp.key_name

    new_result = {
      :type        => self.class.key_pair_type,
      :name        => name,
      :fingerprint => kp.key_fingerprint
    }

    return uid, new_result
  end

  def parse_image_hardware(image)
    uid      = image.image_id
    guest_os = (image.platform == "windows") ? "windows" : "linux"

    new_result = {
      :guest_os            => guest_os,
      :bitness             => architecture_to_bitness(image.architecture),
      :virtualization_type => image.virtualization_type,
      :root_device_type    => image.root_device_type,
      :vm_or_template      => @data[:miq_templates].lazy_find(image.image_id)
    }

    return uid, new_result
  end


  def parse_image(image, is_public)
    get_image_hardware(image)

    uid      = image.image_id
    location = image.image_location

    name = get_from_tags(image, :name)
    name ||= image.name
    name ||= $1 if location =~ /^(.+?)(\.(image|img))?\.manifest\.xml$/
    name ||= uid

    new_result = {
      :type               => ManageIQ::Providers::Amazon::CloudManager::Template.name,
      :uid_ems            => uid,
      :ems_ref            => uid,
      :name               => name,
      :location           => location,
      :vendor             => "amazon",
      :raw_power_state    => "never",
      :template           => true,
      # the is_public flag here avoids having to make an additional API call
      # per image, since we already know whether it's a public image
      :publicly_available => is_public,
    }

    return uid, new_result
  end

  def parse_instance(instance)
    flavor_uid = instance.instance_type
    # Do we need to filter out the disabled flavors? We should just hide them in provision dialog really
    # @known_flavors << flavor_uid
    flavor = @data[:flavors].find(flavor_uid) ||
      @data[:flavors].find("unknown")

    get_instance_hardware(instance, flavor)

    status = instance.state.name
    return if @options.ignore_terminated_instances && status.to_sym == :terminated

    uid  = instance.id
    name = get_from_tags(instance, :name)
    name = name.blank? ? uid : name

    new_result = {
      :type                => ManageIQ::Providers::Amazon::CloudManager::Vm.name,
      :uid_ems             => uid,
      :ems_ref             => uid,
      :name                => name,
      :vendor              => "amazon",
      :raw_power_state     => status,
      :boot_time           => instance.launch_time,
      :availability_zone   => @data[:availability_zones].lazy_find(instance.placement.availability_zone),
      :flavor              => flavor,
      :genealogy_parent    => @data[:miq_templates].lazy_find(instance.image_id),
      :key_pairs           => [@data[:key_pairs].lazy_find(instance.key_name)].compact,
      :location            => @data[:networks].lazy_find("#{uid}__public", :path => [:hostname], :default => 'unknown'),
      :orchestration_stack => @data[:orchestration_stacks].lazy_find(
        get_from_tags(instance, "aws:cloudformation:stack-id")),
    }

    return uid, new_result
  end

  def parse_instance_hardware(instance, flavor)
    get_hardware_networks(instance)
    get_hardware_disks(instance, flavor)

    uid  = instance.id

    new_result = {
      :bitness              => architecture_to_bitness(instance.architecture),
      :virtualization_type  => instance.virtualization_type,
      :root_device_type     => instance.root_device_type,
      :cpu_sockets          => flavor[:cpus],
      :cpu_cores_per_socket => 1,
      :cpu_total_cores      => flavor[:cpus],
      :memory_mb            => flavor[:memory] / 1.megabyte,
      :disk_capacity        => flavor[:ephemeral_disk_size],
      :guest_os             => @data[:hardwares].lazy_find(instance.image_id, :path => [:guest_os]),
      :vm_or_template       => @data[:vms].lazy_find(uid)
    }
    return uid, new_result
  end

  def parse_hardware_public_network(instance)
    new_result = {
      :hardware    => @data[:hardwares].lazy_find(instance.id),
      :ipaddress   => instance.private_ip_address.presence,
      :hostname    => instance.private_dns_name.presence,
      :description => "private"
    }

    new_result = nil if new_result[:ipaddress].blank?

    return nil, new_result
  end

  def parse_hardware_private_network(instance)
    new_result = {
      :hardware    => @data[:hardwares].lazy_find(instance.id),
      :ipaddress   => instance.public_ip_address.presence,
      :hostname    => instance.public_dns_name.presence,
      :description => "public"
    }

    new_result = nil if new_result[:ipaddress].blank?

    return nil, new_result
  end

  def parse_stack(stack)
    uid = stack.stack_id.to_s

    get_stack_resources(stack)
    get_stack_outputs(stack)
    get_stack_parameters(stack)
    get_stack_template(stack)

    new_result = {
      :type                   => ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack.name,
      :ems_ref                => uid,
      :name                   => stack.name,
      :description            => stack.description,
      :status                 => stack.stack_status,
      :status_reason          => stack.stack_status_reason,
      :parent                 => @data[:orchestration_stacks_resources].lazy_find(uid, :path => [:stack]),
      :orchestration_template => @data[:orchestration_templates].lazy_find(stack.stack_id)
    }
    return uid, new_result
  end

  def parse_stack_template(stack)
    # Only need a temporary unique identifier for the template. Using the stack id is the cheapest way.
    uid = stack.stack_id

    new_result = {
      :type        => "OrchestrationTemplateCfn",
      :ems_ref     => uid,
      :name        => stack.name,
      :description => stack.description,
      :content     => stack.client.get_template(:stack_name => stack.name).template_body,
      :orderable   => false
    }
    return uid, new_result
  end

  def parse_stack_parameter(param_key, param_val, stack_id)
    uid = compose_ems_ref(stack_id, param_key)
    new_result = {
      :ems_ref => uid,
      :stack   => @data[:orchestration_stacks].lazy_find(stack_id),
      :name    => param_key,
      :value   => param_val
    }
    return uid, new_result
  end

  def parse_stack_output(output, stack_id)
    uid = compose_ems_ref(stack_id, output.output_key)
    new_result = {
      :ems_ref     => uid,
      :stack       => @data[:orchestration_stacks].lazy_find(stack_id),
      :key         => output.output_key,
      :value       => output.output_value,
      :description => output.description
    }
    return uid, new_result
  end

  def parse_stack_resource(resource, stack_id)
    uid = resource.physical_resource_id
    new_result = {
      :ems_ref                => uid,
      :stack                  => @data[:orchestration_stacks].lazy_find(stack_id),
      :name                   => resource.logical_resource_id,
      :logical_resource       => resource.logical_resource_id,
      :physical_resource      => uid,
      :resource_category      => resource.resource_type,
      :resource_status        => resource.resource_status,
      :resource_status_reason => resource.resource_status_reason,
      :last_updated           => resource.last_updated_timestamp
    }
    return uid, new_result
  end

  class << self
    def key_pair_type
      ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair.name
    end
  end
end
