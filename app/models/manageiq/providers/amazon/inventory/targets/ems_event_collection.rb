class ManageIQ::Providers::Amazon::Inventory::Targets::EmsEventCollection < ManageIQ::Providers::Amazon::Inventory::Targets
  def initialize_inventory_collections
    parse_ems_events!
    add_targeted_inventory_collections
    add_remaining_inventory_collections(:strategy => :local_db_find_one)
  end

  private

  def add_targeted_inventory_collections
    images_refs = private_images_refs + shared_images_refs + public_images_refs

    # Here are fetchers of a special IDs, which are needed because we are creating a fake objects and therefore not
    # using a resourceIds
    instances_public_ips = (instances + instances_deleted).collect do |x|
      # Collect Ips of all EC2 instances, which serve as a fake FloatingIp manager_ref
      x['public_ip_address'] if x['network_interfaces'].blank?
    end.compact
    network_ports_public_ips = (network_ports + network_ports_deleted).collect do |x|
      # Collect Public Ips of all VPC instances, which serve as a fake FloatingIp manager_ref
      x.fetch_path('association', 'public_ip')
    end.compact

    # TODO(lsmola) if we have Interface or possibly VM connected to a public network, we get an IP, if we associate a
    # floating_ip, it replaces the public IP but we do not delete the old Public Ip here. We would need to look into
    # changes:
    # "Configuration.Association.PublicIp"=>
    #     {"previousValue"=>"54.164.17.86",
    #      "updatedValue"=>"54.80.134.186",
    #      "changeType"=>"UPDATE"},

    # Cloud
    add_vms_inventory_collections(instances_refs)
    add_miq_templates_inventory_collections(images_refs)
    add_hardwares_inventory_collections(instances_refs + images_refs)

    # Network
    add_cloud_networks_inventory_collections(cloud_networks_refs)
    add_cloud_subnets_inventory_collections(cloud_subnets_refs)
    add_network_ports_inventory_collections(instances_refs + network_ports_refs)
    add_security_groups_inventory_collections(security_groups_refs)
    add_network_ports_inventory_collections(instances_refs + network_ports_refs)
    add_floating_ips_inventory_collections(instances_public_ips + network_ports_public_ips + floating_ips_refs)
  end

  def add_vms_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      vms_init_data(
        :arel     => ems.vms.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
    add_inventory_collection(
      disks_init_data(
        :arel     => ems.disks.joins(:hardware => :vm_or_template).where(
          :hardware => {:vms => {:ems_ref => manager_refs}}),
        :strategy => :find_missing_in_local_db))
    add_inventory_collection(
      networks_init_data(
        :arel     => ems.networks.joins(:hardware => :vm_or_template).where(
          :hardware => {:vms => {:ems_ref => manager_refs}}),
        :strategy => :find_missing_in_local_db))
  end

  def add_miq_templates_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      miq_templates_init_data(
        :arel     => ems.miq_templates.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
  end

  def add_hardwares_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      hardwares_init_data(
        :arel     => ems.hardwares.joins(:vm_or_template).where(
          :vms => {:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))

  end

  def add_cloud_networks_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      cloud_networks_init_data(
        :arel     => ems.network_manager.cloud_networks.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
  end

  def add_cloud_subnets_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      cloud_subnets_init_data(
        :arel     => ems.network_manager.cloud_subnets.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
  end

  def add_security_groups_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      security_groups_init_data(
        :arel     => ems.network_manager.security_groups.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
    add_inventory_collection(
      firewall_rules_init_data(
        :arel     => ems.network_manager.firewall_rules.references(:security_groups).where(
          :security_groups => {:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))
  end

  def add_network_ports_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      network_ports_init_data(
        :arel     => ems.network_manager.network_ports.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
    add_inventory_collection(
      cloud_subnet_network_ports_init_data(
        :arel     => ems.network_manager.cloud_subnet_network_ports.references(:network_ports).where(
          :network_ports => {:ems_ref => manager_refs}),
        :strategy => :find_missing_in_local_db))
  end

  def add_floating_ips_inventory_collections(manager_refs)
    return if manager_refs.blank?

    add_inventory_collection(
      floating_ips_init_data(
        :arel     => ems.network_manager.floating_ips.where(:ems_ref => manager_refs),
        :strategy => :find_missing_in_local_db))
  end

  def parse_ems_events!
    uniq_checker = {}

    target.all_related_ems_events(ems).each do |ems_event|
      resource_type     = ems_event[:full_data]["configurationItem"]["resourceType"]
      resource_id       = ems_event[:full_data]["configurationItem"]["resourceId"]
      unique_checker_id = "#{resource_type}__#{resource_id}"

      next if resource_type.blank? || resource_id.blank?
      # We take only the last change and ignore the rest. Events are ordered so the last ones come first.
      next if uniq_checker[unique_checker_id]

      uniq_checker[unique_checker_id] = true

      event_payload   = event_payload(ems_event)
      collection_name = case resource_type
                        when "AWS::EC2::Instance"
                          :instances
                        when "AWS::EC2::SecurityGroup"
                          :security_groups
                        when "AWS::EC2::Volume"
                          # We don't have any storage manager
                          nil
                        when "AWS::EC2::NetworkInterface"
                          :network_ports
                        when "AWS::EC2::VPC"
                          :cloud_networks
                        when "AWS::EC2::Subnet"
                          :cloud_subnets
                        when "AWS::EC2::EIP"
                          :floating_ips
                        else
                          # raise error that events is not recognized and fallback to full refresh
                        end
      if collection_name
        # Store events data and ems refs
        if event_payload.present?
          public_send(collection_name) << event_payload
        else
          deleted_payload = event_deleted_payload(ems_event)
          public_send("#{collection_name}_deleted") << deleted_payload
        end
        public_send("#{collection_name}_refs") << resource_id
      end
    end
  end
end
