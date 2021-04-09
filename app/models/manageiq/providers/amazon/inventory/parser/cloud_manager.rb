# TODO: Separate collection from parsing (perhaps collecting in parallel a la RHEVM)

class ManageIQ::Providers::Amazon::Inventory::Parser::CloudManager < ManageIQ::Providers::Amazon::Inventory::Parser
  def parse
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{collector.manager.name}] id: [#{collector.manager.id}]"
    $aws_log.info("#{log_header}...")

    # The order of the below methods does matter, because they are searched using find instead of lazy_find
    flavors

    # The order of the below methods doesn't matter since they refer to each other using only lazy links
    availability_zones
    auth_key_pairs
    stacks
    cloud_database_flavors
    cloud_databases
    private_images if collector.options.get_private_images
    shared_images if collector.options.get_shared_images
    public_images if collector.options.get_public_images
    referenced_images
    instances
    service_offerings
    service_instances

    # The order below matters
    build_and_index_network_routers

    # The order of the below methods doesn't matter since they refer to each other using only lazy links
    cloud_networks
    cloud_subnets
    security_groups
    network_ports
    load_balancers
    ec2_floating_ips_and_ports
    floating_ips

    volumes
    snapshots

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
      name     = image['name'] if name.blank?
      name     = $1 if name.blank? && location =~ /^(.+?)(\.(image|img))?\.manifest\.xml$/
      name     = uid if name.blank?

      persister_image = persister.miq_templates.find_or_build(uid).assign_attributes(
        :uid_ems            => uid,
        :name               => name,
        :location           => location,
        :vendor             => "amazon",
        :connection_state   => "connected",
        :raw_power_state    => "never",
        :template           => true,
        :publicly_available => image['public'],
      )

      image_hardware(persister_image, image)
      image_operating_system(persister_image, image)
      vm_and_template_labels(persister_image, image["tags"] || [])
      vm_and_template_taggings(persister_image, map_labels("Image", image["tags"] || []))
    end
  end

  def image_hardware(persister_image, image)
    guest_os = image['platform'] == "windows" ? "windows_generic" : "linux_generic"
    if guest_os == "linux_generic"
      guest_os = OperatingSystem.normalize_os_name(image['image_location']) if image['image_location']
      guest_os = "linux_generic" if guest_os == "unknown"
    end

    persister.hardwares.find_or_build(persister_image).assign_attributes(
      :guest_os            => guest_os,
      :bitness             => architecture_to_bitness(image['architecture']),
      :virtualization_type => image['virtualization_type'],
      :root_device_type    => image['root_device_type'],
    )
  end

  def image_operating_system(persister_image, image)
    persister.operating_systems.find_or_build(persister_image).assign_attributes(
      # FIXME: duplicated information used by some default reports
      :product_name => persister.hardwares.lazy_find(persister.miq_templates.lazy_find(image['image_id']), :key => :guest_os)
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

  # Returns array of InventoryObject<Tag>.
  def map_labels(model_name, labels)
    label_hashes = labels.collect do |tag|
      {:name => tag["key"], :value => tag["value"]}
    end
    persister.tag_mapper.map_labels(model_name, label_hashes)
  end

  def vm_and_template_taggings(resource, tags_inventory_objects)
    tags_inventory_objects.each do |tag|
      persister.vm_and_template_taggings.build(:taggable => resource, :tag => tag)
    end
  end

  def get_stack_name(stack)
    stack['stack_name'].to_s.presence || stack['stack_id'].to_s.presence
  end

  def stacks
    collector.stacks.each do |stack|
      uid = stack['stack_id'].to_s
      stack_name = get_stack_name(stack)

      persister_orchestration_stack = persister.orchestration_stacks.find_or_build(uid).assign_attributes(
        :name                   => stack_name,
        :description            => stack['description'],
        :status                 => stack['stack_status'],
        :status_reason          => stack['stack_status_reason'],
        :parent                 => persister.orchestration_stacks_resources.lazy_find(uid, :key => :stack),
        :orchestration_template => stack_template(stack)
      )

      stack_resources(persister_orchestration_stack, stack_name)
      stack_outputs(persister_orchestration_stack, stack)
      stack_parameters(persister_orchestration_stack, stack)
    end
  end

  def stack_resources(persister_orchestration_stack, stack_name)
    collector.stack_resources(stack_name).each do |resource|
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
    return unless stack['outputs']

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
    return unless stack['parameters']

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
    stack_name = get_stack_name(stack)
    persister.orchestration_templates.find_or_build(stack['stack_id']).assign_attributes(
      :name        => stack_name,
      :description => stack['description'],
      :content     => collector.stack_template(stack_name),
      :orderable   => false
    )
  end

  def cloud_database_flavors
    collector.cloud_database_flavors.each do |flavor|
      persister.cloud_database_flavors.build(
        :ems_ref => flavor[:name],
        :name    => flavor[:name],
        :enabled => true,
        :cpus    => flavor[:vcpu],
        :memory  => flavor[:memory]
      )
    end
  end

  def cloud_databases
    collector.cloud_databases.each do |cloud_database|
      persister.cloud_databases.build(
        :ems_ref               => cloud_database["dbi_resource_id"],
        :name                  => cloud_database["db_instance_identifier"],
        :status                => cloud_database["db_instance_status"],
        :db_engine             => "#{cloud_database["engine"]} #{cloud_database["engine_version"]}",
        :used_storage          => cloud_database["allocated_storage"]&.gigabytes,
        :max_storage           => cloud_database["max_allocated_storage"]&.gigabytes,
        :cloud_database_flavor => persister.cloud_database_flavors.lazy_find(cloud_database["db_instance_class"])
      )
    end
  end

  def instances
    collector.instances.each do |instance|
      status = instance.fetch_path('state', 'name')
      next if collector.options.ignore_terminated_instances && status.to_sym == :terminated

      flavor = collector.flavors_by_name[instance["instance_type"]] || collector.flavors_by_name["unknown"]

      uid  = instance['instance_id']
      name = get_from_tags(instance, :name) || uid

      lazy_vm = persister.vms.lazy_find(uid)

      persister_instance = persister.vms.find_or_build(uid).assign_attributes(
        :uid_ems             => uid,
        :name                => name,
        :vendor              => "amazon",
        :connection_state    => "connected",
        :raw_power_state     => status,
        :boot_time           => instance['launch_time'],
        :availability_zone   => persister.availability_zones.lazy_find(instance.fetch_path('placement', 'availability_zone')),
        :flavor              => persister.flavors.lazy_find(flavor[:name]),
        :genealogy_parent    => persister.miq_templates.lazy_find(instance['image_id']),
        :key_pairs           => [persister.auth_key_pairs.lazy_find(instance['key_name'])].compact,
        :location            => persister.networks.lazy_find({
                                                               :hardware    => persister.hardwares.lazy_find(:vm_or_template => lazy_vm),
                                                               :description => "public"
                                                             },
                                                             {
                                                               :key     => :hostname,
                                                               :default => 'unknown'
                                                             }),
        :orchestration_stack => persister.orchestration_stacks.lazy_find(
          get_from_tags(instance, "aws:cloudformation:stack-id")
        ),
      )

      instance_hardware(persister_instance, instance, flavor)
      instance_operating_system(persister_instance, instance)
      vm_and_template_labels(persister_instance, instance["tags"] || [])
      vm_and_template_taggings(persister_instance, map_labels("Vm", instance["tags"] || []))
    end
  end

  def instance_hardware(persister_instance, instance, flavor)
    persister_hardware = persister.hardwares.find_or_build(persister_instance).assign_attributes(
      :bitness              => architecture_to_bitness(instance['architecture']),
      :virtualization_type  => instance['virtualization_type'],
      :root_device_type     => instance['root_device_type'],
      :cpu_sockets          => flavor[:vcpu],
      :cpu_cores_per_socket => 1,
      :cpu_total_cores      => flavor[:vcpu],
      :memory_mb            => flavor[:memory] / 1.megabyte,
      :disk_capacity        => flavor[:instance_store_size],
      :guest_os             => persister.hardwares.lazy_find(persister.miq_templates.lazy_find(instance['image_id']), :key => :guest_os),
    )

    hardware_networks(persister_hardware, instance)
    hardware_disks(persister_hardware, instance, flavor)
  end

  def instance_operating_system(persister_instance, instance)
    persister.operating_systems.find_or_build(persister_instance).assign_attributes(
      # FIXME: duplicated information used by some default reports
      :product_name => persister.hardwares.lazy_find(persister.miq_templates.lazy_find(instance['image_id']), :key => :guest_os)
    )
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

    if flavor[:instance_store_volumes] > 0
      single_disk_size = flavor[:instance_store_size] / flavor[:instance_store_volumes]
      flavor[:instance_store_volumes].times do |i|
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

  def auth_key_pairs
    collector.key_pairs.each do |kp|
      persister.auth_key_pairs.find_or_build(kp['key_name']).assign_attributes(
        :fingerprint => kp['key_fingerprint']
      )
    end
  end

  def service_offerings
    collector.service_offerings.each do |service_offering|
      persister_service_offering = persister.service_offerings.build(
        :name    => service_offering.product_view_summary.name,
        :ems_ref => service_offering.product_view_summary.product_id,
        :extra   => {
          :product_view_summary => service_offering.product_view_summary,
          :status               => service_offering.status,
          :product_arn          => service_offering.product_arn,
          :created_time         => service_offering.created_time,
        }
      )

      service_parameters_sets(persister_service_offering)
    end
  end

  def service_parameters_sets(persister_service_offering)
    collector.service_parameters_sets(persister_service_offering.ems_ref).each do |service_parameters_set|
      launch_path = service_parameters_set[:launch_path]
      artifact    = service_parameters_set[:artifact]
      ems_ref     = "#{persister_service_offering.ems_ref}__#{artifact.id}__#{launch_path.id}"

      persister.service_parameters_sets.build(
        :name             => "#{persister_service_offering.name} #{artifact.name} #{launch_path.name}",
        :ems_ref          => ems_ref,
        :service_offering => persister_service_offering,
        :extra            => {
          :artifact                         => artifact,
          :launch_path                      => launch_path,
          :provisioning_artifact_parameters => service_parameters_set[:provisioning_parameters].provisioning_artifact_parameters,
          :constraint_summaries             => service_parameters_set[:provisioning_parameters].constraint_summaries,
          :usage_instructions               => service_parameters_set[:provisioning_parameters].usage_instructions,
        }
      )
    end
  end

  def service_instances
    # TODO(lsmola) a link to orchestration stack is in last_record_outputs

    collector.service_instances.each do |service_instance|
      described_record             = collector.describe_record(service_instance.last_record_id)
      described_record_detail      = described_record&.record_detail
      described_record_outputs     = described_record&.record_outputs
      service_parameters_sets_uuid = "#{described_record_detail.product_id}__#{described_record_detail.provisioning_artifact_id}"\
                                     "__#{described_record_detail.path_id}"

      persister.service_instances.build(
        :name                   => service_instance.name,
        :ems_ref                => service_instance.id,
        :service_offering       => persister.service_offerings.lazy_find(described_record_detail&.product_id),
        :service_parameters_set => persister.service_parameters_sets.lazy_find(service_parameters_sets_uuid),
        :extra                  => {
          :arn                 => service_instance.arn,
          :type                => service_instance.type,
          :status              => service_instance.status,
          :status_message      => service_instance.status_message,
          :created_time        => service_instance.created_time,
          :idempotency_token   => service_instance.idempotency_token,
          :last_record_id      => service_instance.last_record_id,
          :last_record_detail  => described_record_detail,
          :last_record_outputs => described_record_outputs,
        }
      )
    end
  end

  def build_and_index_network_routers
    # We need to pre-calculate NetworkRouter relations, because AWS Subnet api doesn't offer us a foreign_key for each
    # router
    @indexed_routers = {:cloud_subnets_ems_ref => {}, :cloud_networks_ems_ref => {}}

    collector.network_routers.each do |network_router|
      uid              = network_router['route_table_id']
      main_route_table = false

      network_router['associations'].each do |association|
        network_router_lazy = persister.network_routers.lazy_find(uid)
        if association['main']
          main_route_table                                                    = true
          @indexed_routers[:cloud_networks_ems_ref][network_router['vpc_id']] = network_router_lazy
        else
          @indexed_routers[:cloud_subnets_ems_ref][association['subnet_id']] = network_router_lazy
        end
      end

      persister.network_routers.find_or_build(uid).assign_attributes(
        :cloud_network    => persister.cloud_networks.lazy_find(network_router['vpc_id']),
        :status           => network_router['routes'].all? { |x| x['state'] == 'active' } ? 'active' : 'inactive',
        :name             => get_from_tags(network_router, "Name") || uid,
        :extra_attributes => {
          :main_route_table => main_route_table,
          :routes           => network_router['routes'],
          :propagating_vgws => network_router['propagating_vgws']
        },
        # TODO(lsmola) model orchestration_stack_id relation for a NetworkRouter
        # :orchestration_stack => persister.orchestration_stacks.lazy_find(get_from_tags(network_router, "aws:cloudformation:stack-id")),
      )
    end
  end

  def cloud_networks
    collector.cloud_networks.each do |vpc|
      persister.cloud_networks.find_or_build(vpc['vpc_id']).assign_attributes(
        :name                => get_from_tags(vpc, 'name') || vpc['vpc_id'],
        :cidr                => vpc['cidr_block'],
        :status              => vpc['state'] == "available" ? "active" : "inactive",
        :enabled             => true,
        :orchestration_stack => persister.orchestration_stacks.lazy_find(
          get_from_tags(vpc, "aws:cloudformation:stack-id")
        ),
      )
    end
  end

  def cloud_subnets
    collector.cloud_subnets.each do |subnet|
      persister_cloud_subnet = persister.cloud_subnets.find_or_build(subnet['subnet_id']).assign_attributes(
        :name              => get_from_tags(subnet, 'name') || subnet['subnet_id'],
        :cidr              => subnet['cidr_block'],
        :status            => subnet['state'].try(:to_s),
        :availability_zone => persister.availability_zones.lazy_find(subnet['availability_zone']),
        :cloud_network     => persister.cloud_networks.lazy_find(subnet['vpc_id']),
      )

      network_router_lazy = @indexed_routers[:cloud_subnets_ems_ref][subnet['subnet_id']] || @indexed_routers[:cloud_networks_ems_ref][subnet['vpc_id']]
      persister_cloud_subnet.network_router = network_router_lazy if network_router_lazy
    end
  end

  def security_groups
    collector.security_groups.each do |sg|
      persister_security_group = persister.security_groups.find_or_build(sg['group_id']).assign_attributes(
        :name                => get_from_tags(sg, 'name') || sg['group_name'].presence || sg['group_id'],
        :description         => sg['description'].try(:truncate, 255),
        :cloud_network       => persister.cloud_networks.lazy_find(sg['vpc_id']),
        :orchestration_stack => persister.orchestration_stacks.lazy_find(
          get_from_tags(sg, "aws:cloudformation:stack-id")
        ),
      )

      sg['ip_permissions'].each { |perm| firewall_rule(persister_security_group, perm, "inbound") }
      sg['ip_permissions_egress'].each { |perm| firewall_rule(persister_security_group, perm, "outbound") }
    end
  end

  # TODO: Should ICMP protocol values have their own 2 columns, or
  #   should they override port and end_port like the Amazon API.
  def firewall_rule(persister_security_group, perm, direction)
    common = {
      :direction             => direction,
      :host_protocol         => perm['ip_protocol'].to_s == "-1" ? _("All") : perm['ip_protocol'].to_s.upcase,
      :port                  => perm['from_port'],
      :end_port              => perm['to_port'],
      :resource              => persister_security_group,
      :source_security_group => nil,
      :source_ip_range       => nil,
    }

    (perm['user_id_group_pairs'] || []).each do |g|
      firewall_rule                         = common.dup
      firewall_rule[:source_security_group] = persister.security_groups.lazy_find(g['group_id'])
      persister.firewall_rules.build(firewall_rule)
    end

    (perm['ip_ranges'] || []).each do |r|
      firewall_rule                   = common.dup
      firewall_rule[:source_ip_range] = r['cidr_ip']
      persister.firewall_rules.build(firewall_rule)
    end

    (perm['ipv_6_ranges'] || []).each do |r|
      firewall_rule                   = common.dup
      firewall_rule[:source_ip_range] = r['cidr_ipv_6']
      persister.firewall_rules.build(firewall_rule)
    end
  end

  def load_balancers
    collector.load_balancers.each do |lb|
      uid = lb['load_balancer_name']

      persister_load_balancer = persister.load_balancers.find_or_build(uid).assign_attributes(
        :name => uid,
      )

      persister_load_balancer_pool = persister.load_balancer_pools.find_or_build(uid).assign_attributes(
        :name => uid,
      )

      load_balancer_pool_members(persister_load_balancer_pool, lb['instances'])
      load_balancer_listeners(persister_load_balancer, persister_load_balancer_pool, lb)
      load_balancer_health_checks(persister_load_balancer, uid, lb['health_check'])
      load_balancer_floating_ip_and_port(persister_load_balancer, uid, lb)
    end
  end

  def load_balancer_pool_members(persister_load_balancer_pool, members)
    members.each do |member|
      uid = member['instance_id']

      persister_load_balancer_pool_member = persister.load_balancer_pool_members.find_or_build(uid).assign_attributes(
        # TODO(lsmola) AWS always associates to eth0 of the instances, we do not collect that info now, we need to do that
        # :network_port => get eth0 network_port
        :vm => persister.vms.lazy_find(uid)
      )

      persister.load_balancer_pool_member_pools.find_or_build_by(
        :load_balancer_pool        => persister_load_balancer_pool,
        :load_balancer_pool_member => persister_load_balancer_pool_member
      )
    end
  end

  def load_balancer_listeners(persister_load_balancer, persister_load_balancer_pool, lb)
    lb['listener_descriptions'].each do |listener|
      listener = listener['listener']
      uid      = "#{lb['load_balancer_name']}__#{listener['protocol']}__#{listener['load_balancer_port']}__"\
                 "#{listener['instance_protocol']}__#{listener['instance_port']}__#{listener['ssl_certificate_id']}"

      persister_load_balancer_listener = persister.load_balancer_listeners.find_or_build(uid).assign_attributes(
        :load_balancer_protocol   => listener['protocol'],
        :load_balancer_port_range => (listener['load_balancer_port'].to_i..listener['load_balancer_port'].to_i),
        :instance_protocol        => listener['instance_protocol'],
        :instance_port_range      => (listener['instance_port'].to_i..listener['instance_port'].to_i),
        :load_balancer            => persister_load_balancer,
      )

      persister.load_balancer_listener_pools.find_or_build_by(
        :load_balancer_listener => persister_load_balancer_listener,
        :load_balancer_pool     => persister_load_balancer_pool
      )
    end
  end

  def load_balancer_health_checks(persister_load_balancer, uid, health_check)
    target_match = health_check['target'].match(/^(\w+)\:(\d+)\/?(.*?)$/)
    protocol     = target_match[1]
    port         = target_match[2].to_i
    url_path     = target_match[3]

    persister_load_balancer_health_check = persister.load_balancer_health_checks.find_or_build(uid).assign_attributes(
      :protocol            => protocol,
      :port                => port,
      :url_path            => url_path,
      :interval            => health_check['interval'],
      :timeout             => health_check['timeout'],
      :unhealthy_threshold => health_check['unhealthy_threshold'],
      :healthy_threshold   => health_check['healthy_threshold'],
      :load_balancer       => persister_load_balancer,
    )

    load_balancer_health_checks_members(persister_load_balancer_health_check, uid)
  end

  def load_balancer_floating_ip_and_port(persister_load_balancer, uid, lb)
    persister_network_port = persister.network_ports.find_or_build(uid).assign_attributes(
      :name            => uid,
      :status          => nil,
      :mac_address     => nil,
      :device_owner    => uid,
      :device_ref      => uid,
      :device          => persister_load_balancer,
      :security_groups => lb['security_groups'].to_a.collect do |security_group_id|
        persister.security_groups.lazy_find(security_group_id)
      end.compact,
    )

    lb['subnets'].each do |subnet_id|
      persister.cloud_subnet_network_ports.find_or_build_by(
        :address      => nil,
        :cloud_subnet => persister.cloud_subnets.lazy_find(subnet_id),
        :network_port => persister_network_port
      )
    end

    persister.floating_ips.find_or_build(uid).assign_attributes(
      :address            => lb['dns_name'],
      :fixed_ip_address   => nil,
      :cloud_network_only => lb['vpc_id'].present?,
      :network_port       => persister_network_port,
      :cloud_network      => lb['vpc_id'].present? ? persister.cloud_networks.lazy_find(lb['vpc_id']) : nil,
      :status             => nil,
      :vm                 => nil
    )
  end

  def load_balancer_health_checks_members(persister_load_balancer_health_check, uid)
    collector.health_check_members(uid).each do |member|
      persister.load_balancer_health_check_members.find_or_build_by(
        :load_balancer_health_check => persister_load_balancer_health_check,
        :load_balancer_pool_member  => persister.load_balancer_pool_members.lazy_find(member['instance_id']),
      ).assign_attributes(
        :status        => member['state'],
        :status_reason => member['description']
      )
    end
  end

  def floating_ips
    collector.floating_ips.each do |ip|
      cloud_network_only = ip['domain']['vpc'] ? true : false
      address            = ip['public_ip']
      uid                = cloud_network_only ? ip['allocation_id'] : ip['public_ip']

      # These are solved by the ec2_floating_ips_and_ports and they need to be solved there. Seems like there is a bug
      # that the private ip is not present in this list, but it's under ec2_floating_ips_and_ports ips, but only for
      # the non VPC instances.
      next if !cloud_network_only && ip['instance_id'] && persister.floating_ips.primary_index.find(uid)

      persister.floating_ips.find_or_build(uid).assign_attributes(
        :address            => address,
        :fixed_ip_address   => ip['private_ip_address'],
        :cloud_network_only => cloud_network_only,
        :network_port       => persister.network_ports.lazy_find(ip['network_interface_id']),
        :vm                 => persister.vms.lazy_find(ip['instance_id'])
      )
    end
  end

  def network_ports
    collector.network_ports.each do |network_port|
      uid             = network_port['network_interface_id']
      security_groups = network_port['groups'].blank? ? [] : network_port['groups'].map do |x|
        persister.security_groups.lazy_find(x['group_id'])
      end

      persister_network_port = persister.network_ports.find_or_build(uid).assign_attributes(
        :name            => get_from_tags(network_port, 'name') || uid,
        :status          => network_port['status'],
        :mac_address     => network_port['mac_address'],
        :device_owner    => network_port.fetch_path('attachment', 'instance_owner_id'),
        :device_ref      => network_port.fetch_path('attachment', 'instance_id'),
        :device          => persister.vms.lazy_find(network_port.fetch_path('attachment', 'instance_id')),
        :security_groups => security_groups,
      )

      network_port['private_ip_addresses'].each do |address|
        persister.cloud_subnet_network_ports.find_or_build_by(
          :address      => address['private_ip_address'],
          :cloud_subnet => persister.cloud_subnets.lazy_find(network_port['subnet_id']),
          :network_port => persister_network_port
        )
      end

      public_ips(network_port)
    end
  end

  def public_ips(network_port)
    network_port['private_ip_addresses'].each do |private_address|
      if private_address['association'] &&
         !(public_ip = private_address.fetch_path('association', 'public_ip')).blank? &&
         private_address.fetch_path('association', 'allocation_id').blank?

        persister.floating_ips.find_or_build(public_ip).assign_attributes(
          :address            => public_ip,
          :fixed_ip_address   => private_address['private_ip_address'],
          :cloud_network_only => true,
          :network_port       => persister.network_ports.lazy_find(network_port['network_interface_id']),
          :vm                 => persister.network_ports.lazy_find(network_port['network_interface_id'],
                                                                   :key => :device)
        )
      end
    end
  end

  def ec2_floating_ips_and_ports
    collector.instances.each do |instance|
      next unless instance['network_interfaces'].blank?

      persister_network_port = persister.network_ports.find_or_build(instance['instance_id']).assign_attributes(
        :name            => get_from_tags(instance, 'name') || instance['instance_id'],
        :status          => nil,
        :mac_address     => nil,
        :device_owner    => nil,
        :device_ref      => nil,
        :device          => persister.vms.lazy_find(instance['instance_id']),
        :security_groups => instance['security_groups'].to_a.collect do |sg|
          persister.security_groups.lazy_find(sg['group_id'])
        end.compact,
      )

      persister.cloud_subnet_network_ports.find_or_build_by(
        :address      => instance['private_ip_address'],
        :cloud_subnet => nil,
        :network_port => persister_network_port
      )

      floating_ip_inferred_from_instance(persister_network_port, instance)
    end
  end

  def floating_ip_inferred_from_instance(persister_network_port, instance)
    uid = instance['public_ip_address']
    return nil if uid.blank?

    persister.floating_ips.find_or_build(uid).assign_attributes(
      :address            => uid,
      :fixed_ip_address   => instance['private_ip_address'],
      :cloud_network_only => false,
      :network_port       => persister_network_port,
      :vm                 => persister_network_port.device
    )
  end

  def volumes
    collector.cloud_volumes.each do |volume|
      persister_volume = persister.cloud_volumes.find_or_build(volume['volume_id']).assign_attributes(
        :name              => get_from_tags(volume, :name) || volume['volume_id'],
        :status            => volume['state'],
        :creation_time     => volume['create_time'],
        :volume_type       => volume['volume_type'],
        :size              => volume['size'].to_i.gigabytes,
        :base_snapshot     => persister.cloud_volume_snapshots.lazy_find(volume['snapshot_id']),
        :availability_zone => persister.availability_zones.lazy_find(volume['availability_zone']),
        :iops              => volume['iops'],
        :encrypted         => volume['encrypted'],
      )

      volume_attachments(persister_volume, volume['attachments'])
    end
  end

  def snapshots
    collector.cloud_volume_snapshots.each do |snap|
      persister.cloud_volume_snapshots.find_or_build(snap['snapshot_id']).assign_attributes(
        :name          => get_from_tags(snap, :name) || snap['snapshot_id'],
        :status        => snap['state'],
        :creation_time => snap['start_time'],
        :description   => snap['description'],
        :size          => snap['volume_size'].to_i.gigabytes,
        :cloud_volume  => persister.cloud_volumes.lazy_find(snap['volume_id']),
        :encrypted     => snap['encrypted'],
      )
    end
  end

  def volume_attachments(persister_volume, attachments)
    (attachments || []).each do |a|
      if a['device'].blank?
        log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{collector.manager.name}] id: [#{collector.manager.id}]"
        $aws_log.warn "#{log_header}: Volume: #{persister_volume.ems_ref}, is missing a mountpoint, skipping the volume processing"
        $aws_log.warn "#{log_header}: EMS: #{collector.manager.name}, Instance: #{a['instance_id']}"
        next
      end

      dev = File.basename(a['device'])

      persister.disks.find_or_build_by(
        :hardware    => persister.hardwares.lazy_find(persister.vms.lazy_find(a["instance_id"])),
        :device_name => dev
      ).assign_attributes(
        :location => dev,
        :size     => persister_volume.size,
        :backing  => persister_volume,
      )
    end
  end
end
