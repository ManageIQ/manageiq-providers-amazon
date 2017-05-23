# TODO: Separate collection from parsing (perhaps collecting in parallel a la RHEVM)

class ManageIQ::Providers::Amazon::Inventory::Parser::CloudManager < ManageIQ::Providers::Amazon::Inventory::Parser
  def parse
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{collector.manager.name}] id: [#{collector.manager.id}]"
    $aws_log.info("#{log_header}...")
    # The order of the below methods does matter, because they are searched using find instead of lazy_find
    flavors

    # The order of the below methods doesn't matter since they refer to each other using only lazy links
    availability_zones
    key_pairs
    stacks
    private_images if collector.options.get_private_images
    shared_images if collector.options.get_shared_images
    public_images if collector.options.get_public_images
    referenced_images
    instances

    $aws_log.info("#{log_header}...Complete")
  end

  private

  def private_images
    images(collector.private_images)
  end

  def shared_images
    images(collector.shared_images)
  end

  def public_images
    images(collector.public_images)
  end

  def referenced_images
    images(collector.referenced_images)
  end

  def images(images)
    images.each do |image|
      uid      = image['image_id']
      location = image['image_location']
      name     = get_from_tags(image, :name)
      name     ||= image['name']
      name     ||= $1 if location =~ /^(.+?)(\.(image|img))?\.manifest\.xml$/
      name     ||= uid

      persister_image = persister.miq_templates.find_or_build(uid).assign_attributes(
        :uid_ems            => uid,
        :name               => name,
        :location           => location,
        :vendor             => "amazon",
        :raw_power_state    => "never",
        :template           => true,
        :publicly_available => image['public'],
      )

      image_hardware(persister_image, image)
      vm_and_template_labels(persister_image, image["tags"] || [])
    end
  end

  def image_hardware(persister_image, image)
    guest_os = image['platform'] == "windows" ? "windows" : "linux"
    if guest_os == "linux"
      guest_os = OperatingSystem.normalize_os_name(image['image_location'])
      guest_os = "linux" if guest_os == "unknown"
    end

    persister.hardwares.find_or_build(persister_image).assign_attributes(
      :guest_os            => guest_os,
      :bitness             => architecture_to_bitness(image['architecture']),
      :virtualization_type => image['virtualization_type'],
      :root_device_type    => image['root_device_type'],
    )
  end

  def vm_and_template_labels(resource, tags)
    tags.each do |tag|
      persister.vm_and_template_labels.find_or_build_by(:resource => resource, :name => tag["key"]).assign_attributes(
        :section => 'labels',
        :value   => tag["value"],
        :source  => 'amazon'
      )
    end
  end

  def stacks
    collector.stacks.each do |stack|
      uid = stack['stack_id'].to_s

      persister_orchestration_stack = persister.orchestration_stacks.find_or_build(uid).assign_attributes(
        :name                   => stack['stack_name'],
        :description            => stack['description'],
        :status                 => stack['stack_status'],
        :status_reason          => stack['stack_status_reason'],
        :parent                 => persister.orchestration_stacks_resources.lazy_find(uid, :key => :stack),
        :orchestration_template => stack_template(stack)
      )

      stack_resources(persister_orchestration_stack, stack)
      stack_outputs(persister_orchestration_stack, stack)
      stack_parameters(persister_orchestration_stack, stack)
    end
  end

  def stack_resources(persister_orchestration_stack, stack)
    collector.stack_resources(stack['stack_name']).each do |resource|
      uid = resource['physical_resource_id']
      # physical_resource_id can be empty if the resource was not successfully created; ignore such
      return nil if uid.nil?

      persister.orchestration_stacks_resources.find_or_build(uid).assign_attributes(
        :stack                  => persister_orchestration_stack,
        :name                   => resource['logical_resource_id'],
        :logical_resource       => resource['logical_resource_id'],
        :physical_resource      => uid,
        :resource_category      => resource['resource_type'],
        :resource_status        => resource['resource_status'],
        :resource_status_reason => resource['resource_status_reason'],
        :last_updated           => resource['last_updated_timestamp']
      )
    end
  end

  def stack_outputs(persister_orchestration_stack, stack)
    stack['outputs'].each do |output|
      uid = compose_ems_ref(stack['stack_id'].to_s, output['output_key'])

      persister.orchestration_stacks_outputs.find_or_build(uid).assign_attributes(
        :stack       => persister_orchestration_stack,
        :key         => output['output_key'],
        :value       => output['output_value'],
        :description => output['description']
      )
    end
  end

  def stack_parameters(persister_orchestration_stack, stack)
    stack['parameters'].each do |parameter|
      uid = compose_ems_ref(stack['stack_id'].to_s, parameter['parameter_key'])

      persister.orchestration_stacks_parameters.find_or_build(uid).assign_attributes(
        :stack => persister_orchestration_stack,
        :name  => parameter['parameter_key'],
        :value => parameter['parameter_value']
      )
    end
  end

  def stack_template(stack)
    persister.orchestration_templates.find_or_build(stack['stack_id']).assign_attributes(
      :name        => stack['stack_name'],
      :description => stack['description'],
      :content     => collector.stack_template(stack['stack_name']),
      :orderable   => false
    )
  end

  def instances
    collector.instances.each do |instance|
      status = instance.fetch_path('state', 'name')
      next if collector.options.ignore_terminated_instances && status.to_sym == :terminated

      # TODO(lsmola) we have a non lazy dependency, can we remove that?
      flavor = persister.flavors.find(instance['instance_type']) || persister.flavors.find("unknown")

      uid  = instance['instance_id']
      name = get_from_tags(instance, :name)
      name = name.blank? ? uid : name

      persister_instance = persister.vms.find_or_build(uid).assign_attributes(
        :uid_ems             => uid,
        :name                => name,
        :vendor              => "amazon",
        :raw_power_state     => status,
        :boot_time           => instance['launch_time'],
        :availability_zone   => persister.availability_zones.lazy_find(instance.fetch_path('placement', 'availability_zone')),
        :flavor              => flavor,
        :genealogy_parent    => persister.miq_templates.lazy_find(instance['image_id']),
        :key_pairs           => [persister.key_pairs.lazy_find(instance['key_name'])].compact,
        :location            => persister.networks.lazy_find("#{uid}__public", :key => :hostname, :default => 'unknown'),
        :orchestration_stack => persister.orchestration_stacks.lazy_find(
          get_from_tags(instance, "aws:cloudformation:stack-id")
        ),
      )

      instance_hardware(persister_instance, instance, flavor)
      vm_and_template_labels(persister_instance, instance["tags"] || [])
    end
  end

  def instance_hardware(persister_instance, instance, flavor)
    persister_hardware = persister.hardwares.find_or_build(persister_instance).assign_attributes(
      :bitness              => architecture_to_bitness(instance['architecture']),
      :virtualization_type  => instance['virtualization_type'],
      :root_device_type     => instance['root_device_type'],
      :cpu_sockets          => flavor[:cpus],
      :cpu_cores_per_socket => 1,
      :cpu_total_cores      => flavor[:cpus],
      :memory_mb            => flavor[:memory] / 1.megabyte,
      :disk_capacity        => flavor[:ephemeral_disk_size],
      :guest_os             => persister.hardwares.lazy_find(instance['image_id'], :key => :guest_os),
    )

    hardware_networks(persister_hardware, instance)
    hardware_disks(persister_hardware, instance, flavor)
  end

  def hardware_networks(persister_hardware, instance)
    hardware_network(persister_hardware,
                     instance['private_ip_address'].presence,
                     instance['private_dns_name'].presence,
                     "private")

    hardware_network(persister_hardware,
                     instance['public_ip_address'].presence,
                     instance['public_dns_name'].presence,
                     "public")
  end

  def hardware_network(persister_hardware, ip_address, hostname, description)
    unless ip_address.blank?
      persister.networks.find_or_build_by(
        :hardware    => persister_hardware,
        :description => description
      ).assign_attributes(
        :ipaddress => ip_address,
        :hostname  => hostname,
      )
    end
  end

  def hardware_disks(persister_hardware, instance, flavor)
    disks = []

    if flavor[:ephemeral_disk_count] > 0
      single_disk_size = flavor[:ephemeral_disk_size] / flavor[:ephemeral_disk_count]
      flavor[:ephemeral_disk_count].times do |i|
        add_instance_disk(disks, single_disk_size, i, "Disk #{i}")
      end
    end

    if instance.key?("block_device_mappings")
      instance["block_device_mappings"].each do |blk_map|
        device = File.basename(blk_map["device_name"])
        add_block_device_disk(disks, device, device)
      end
    end

    disks.each do |disk|
      disk[:hardware] = persister_hardware

      persister.disks.find_or_build_by(
        :hardware    => persister_hardware,
        :device_name => disk[:device_name]
      ).assign_attributes(disk)
    end
  end

  def flavors
    collector.flavors.each do |flavor|
      persister.flavors.find_or_build(flavor[:name]).assign_attributes(
        :name                     => flavor[:name],
        :description              => flavor[:description],
        :enabled                  => !flavor[:disabled],
        :cpus                     => flavor[:vcpu],
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
      )
    end
  end

  def availability_zones
    collector.availability_zones.each do |az|
      persister.availability_zones.find_or_build(az['zone_name']).assign_attributes(
        :name => az['zone_name'],
      )
    end
  end

  def key_pairs
    collector.key_pairs.each do |kp|
      persister.key_pairs.find_or_build(kp['key_name']).assign_attributes(
        :fingerprint => kp['key_fingerprint']
      )
    end
  end
end
