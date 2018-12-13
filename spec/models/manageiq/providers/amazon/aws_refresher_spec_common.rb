require "inventory_refresh"

module AwsRefresherSpecCommon
  extend ActiveSupport::Concern

  included do
    # We need a relative path so the specs are executable from the core
    VCR.configure do |c|
      c.cassette_library_dir = File.join(File.dirname(__FILE__), "../" * 4 + "vcr_cassettes")
    end
  end

  ALL_GRAPH_REFRESH_SETTINGS = [
    {
      :inventory_object_refresh => true,
      :inventory_collections    => {
        :saver_strategy => "default",
      },
    }, {
      :inventory_object_refresh => true,
      :inventory_collections    => {
        :saver_strategy => "batch",
        :use_ar_object  => true,
      },
    }, {
      :inventory_object_refresh => true,
      :inventory_collections    => {
        :saver_strategy => "batch",
        :use_ar_object  => false,
      },
    }, {
      :inventory_object_saving_strategy => :recursive,
      :inventory_object_refresh         => true
    }
  ].freeze

  ALL_OLD_REFRESH_SETTINGS = [
    {
      :inventory_object_refresh => false
    }
  ].freeze

  def stub_refresh_settings(settings)
    # TODO(lsmola) extract the batch sizes to the settings and stub the settings instead
    # Lower batch sizes to test multiple batches for each collection
    allow_any_instance_of(InventoryRefresh::InventoryCollection).to receive(:batch_size).and_return(4)
    allow_any_instance_of(InventoryRefresh::InventoryCollection).to receive(:batch_size_pure_sql).and_return(4)

    stub_settings_merge(
      :ems_refresh => {
        :ec2             => settings,
        :ec2_network     => settings,
        :ec2_ebs_storage => settings,
        :s3              => settings
      }
    )
  end

  def assert_common
    expect(@ems.direct_orchestration_stacks.size).to eql(7)
    assert_specific_flavor
    assert_specific_az
    assert_specific_key_pair
    assert_specific_cloud_network
    assert_specific_security_group
    assert_specific_security_group_on_cloud_network
    assert_specific_template
    assert_specific_template_2
    assert_specific_shared_template
    assert_specific_cloud_volume_vm_on_cloud_network
    assert_specific_cloud_volume_vm_on_cloud_network_public_ip
    assert_specific_cloud_volume_snapshot
    assert_specific_cloud_volume_snapshot_encrypted
    assert_specific_vm_powered_on
    assert_specific_vm_powered_off
    assert_specific_vm_on_cloud_network
    assert_specific_vm_on_cloud_network_public_ip
    assert_specific_vm_in_other_region
    assert_specific_load_balancers
    assert_specific_load_balancer_listeners
    assert_specific_load_balancer_health_checks
    assert_specific_orchestration_template
    assert_specific_orchestration_stack
    assert_network_router
    assert_relationship_tree
    assert_specific_labels_on_vm

    if options.inventory_object_refresh
      assert_specific_service_offerings
      assert_specific_service_instances
    end
  end

  def assert_specific_flavor
    @flavor = ManageIQ::Providers::Amazon::CloudManager::Flavor.where(:name => "t1.micro").first
    expect(@flavor).to(
      have_attributes(
        :name                     => "t1.micro",
        :ems_ref                  => "t1.micro",
        :description              => "T1 Micro",
        :enabled                  => true,
        :cpus                     => 1,
        :cpu_cores                => 1,
        :memory                   => 0.613.gigabytes.to_i,
        :supports_32_bit          => true,
        :supports_64_bit          => true,
        :supports_hvm             => false,
        :supports_paravirtual     => true,
        :block_storage_based_only => true,
        :ephemeral_disk_size      => 0,
        :ephemeral_disk_count     => 0
      )
    )

    expect(@flavor.ext_management_system).to eq(@ems)
  end

  def assert_specific_az
    @az = ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.where(:name => "us-east-1e").first
    expect(@az).to have_attributes(
      :name => "us-east-1e",
    )
  end

  def assert_specific_floating_ip
    @ip = ManageIQ::Providers::Amazon::NetworkManager::FloatingIp.where(:address => "54.221.202.53").first
    expect(@ip).to have_attributes(
      :address            => "54.221.202.53",
      :fixed_ip_address   => "10.91.143.248",
      :ems_ref            => "54.221.202.53",
      :cloud_network_only => false
    )
  end

  def assert_specific_floating_ip_for_cloud_network
    @ip1 = ManageIQ::Providers::Amazon::NetworkManager::FloatingIp.where(:address => "54.208.119.197").first
    expect(@ip1).to have_attributes(
      :address            => "54.208.119.197",
      :fixed_ip_address   => "10.0.0.254",
      :ems_ref            => "eipalloc-ce53d7a0",
      :cloud_network_only => true
    )
  end

  def assert_specific_public_ip_for_cloud_network
    @ip2 = ManageIQ::Providers::Amazon::NetworkManager::FloatingIp.where(:address => "54.208.71.4").first
    expect(@ip2).to have_attributes(
      :address            => "54.208.71.4",
      :fixed_ip_address   => "10.0.0.122",
      :ems_ref            => "54.208.71.4",
      :cloud_network_only => true
    )
  end

  def assert_specific_key_pair
    @kp = ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair.where(:name => "EmsRefreshSpec-KeyPair").first
    expect(@kp).to have_attributes(
      :name        => "EmsRefreshSpec-KeyPair",
      :fingerprint => "49:9f:3f:a4:26:48:39:94:26:06:dd:25:73:e5:da:9b:4b:1b:6c:93"
    )
  end

  def assert_vpc
    @cn = ManageIQ::Providers::Amazon::NetworkManager::CloudNetwork.where(:name => "EmsRefreshSpec-VPC").first
    expect(@cn).to(
      have_attributes(
        :name    => "EmsRefreshSpec-VPC",
        :ems_ref => "vpc-ff49ff91",
        :cidr    => "10.0.0.0/16",
        :status  => "active",
        :enabled => true
      )
    )
  end

  def assert_vpc_subnet_1
    @subnet = @cn.cloud_subnets.where(:name => "EmsRefreshSpec-Subnet1").first
    expect(@subnet).to(
      have_attributes(
        :type    => "ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet",
        :name    => "EmsRefreshSpec-Subnet1",
        :ems_ref => "subnet-f849ff96",
        :cidr    => "10.0.0.0/24"
      )
    )
    expect(@subnet.availability_zone)
      .to eq(ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.where(:name => "us-east-1e").first)
  end

  def assert_vpc_subnet_2
    subnet2 = @cn.cloud_subnets.where(:name => "EmsRefreshSpec-Subnet2").first
    expect(subnet2).to(
      have_attributes(
        :type    => "ManageIQ::Providers::Amazon::NetworkManager::CloudSubnet",
        :name    => "EmsRefreshSpec-Subnet2",
        :ems_ref => "subnet-16c70477",
        :cidr    => "10.0.1.0/24"
      )
    )
    expect(subnet2.availability_zone)
      .to eq(ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.where(:name => "us-east-1d").first)
  end

  def assert_specific_cloud_network
    assert_vpc
    expect(@cn.cloud_subnets.size).to eq(3)
    assert_vpc_subnet_1
    assert_vpc_subnet_2
  end

  def assert_specific_security_group
    @sg = ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup.where(:name => "EmsRefreshSpec-SecurityGroup1").first
    expect(@sg).to have_attributes(
      :name        => "EmsRefreshSpec-SecurityGroup1",
      :description => "EmsRefreshSpec-SecurityGroup1",
      :ems_ref     => "sg-038e8a69"
    )

    expected_firewall_rules = [
      {:host_protocol => "ICMP", :direction => "inbound", :port => -1, :end_port => -1,     :source_ip_range => "0.0.0.0/0",  :source_security_group_id => nil},
      {:host_protocol => "ICMP", :direction => "inbound", :port => -1, :end_port => -1,     :source_ip_range => nil,          :source_security_group_id => @sg.id},
      {:host_protocol => "ICMP", :direction => "inbound", :port => 0,  :end_port => -1,     :source_ip_range => "1.2.3.4/30", :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 0,  :end_port => 65_535, :source_ip_range => "0.0.0.0/0",  :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 1,  :end_port => 2,      :source_ip_range => "1.2.3.4/30", :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 3,  :end_port => 4,      :source_ip_range => nil,          :source_security_group_id => @sg.id},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 80, :end_port => 80,     :source_ip_range => "0.0.0.0/0",  :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 80, :end_port => 80,     :source_ip_range => "1.2.3.4/30", :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 80, :end_port => 80,     :source_ip_range => nil,          :source_security_group_id => @sg.id},
      {:host_protocol => "UDP",  :direction => "inbound", :port => 0,  :end_port => 65_535, :source_ip_range => "0.0.0.0/0",  :source_security_group_id => nil},
      {:host_protocol => "UDP",  :direction => "inbound", :port => 1,  :end_port => 2,      :source_ip_range => "1.2.3.4/30", :source_security_group_id => nil},
      {:host_protocol => "UDP",  :direction => "inbound", :port => 3,  :end_port => 4,      :source_ip_range => nil,          :source_security_group_id => @sg.id}
    ]

    expect(@sg.firewall_rules.size).to eq(12)
    @sg.firewall_rules
       .order(:host_protocol, :direction, :port, :end_port, :source_ip_range, :source_security_group_id)
       .zip(expected_firewall_rules)
       .each do |actual, expected|
      expect(actual).to have_attributes(expected)
    end
  end

  def assert_specific_security_group_on_cloud_network
    @sg_on_cn = ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup.where(:name => "EmsRefreshSpec-SecurityGroup-VPC").first
    expect(@sg_on_cn).to have_attributes(
      :name        => "EmsRefreshSpec-SecurityGroup-VPC",
      :description => "EmsRefreshSpec-SecurityGroup-VPC",
      :ems_ref     => "sg-80f755ef"
    )

    expect(@sg_on_cn.cloud_network).to eq(@cn)
  end

  def assert_specific_template
    @template = ManageIQ::Providers::Amazon::CloudManager::Template.where(:name => "EmsRefreshSpec-Image").first
    expect(@template).to have_attributes(
      :template              => true,
      :ems_ref               => "ami-5769193e",
      :ems_ref_obj           => nil,
      :uid_ems               => "ami-5769193e",
      :vendor                => "amazon",
      :power_state           => "never",
      :publicly_available    => false,
      :location              => "200278856672/EmsRefreshSpec-Image",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => "connected",
      :cpu_affinity          => nil,
      :memory_reserve        => nil,
      :memory_reserve_expand => nil,
      :memory_limit          => nil,
      :memory_shares         => nil,
      :memory_shares_level   => nil,
      :cpu_reserve           => nil,
      :cpu_reserve_expand    => nil,
      :cpu_limit             => nil,
      :cpu_shares            => nil,
      :cpu_shares_level      => nil
    )

    expect(@template.ext_management_system).to eq(@ems)
    expect(@template.operating_system).to(
      have_attributes(
        :product_name => "linux_generic",
      )
    )
    expect(@template.custom_attributes.size).to eq(1)
    expect(@template.snapshots.size).to eq(0)

    expect(@template.hardware).to have_attributes(
      :guest_os            => "linux_generic",
      :guest_os_full_name  => nil,
      :bios                => nil,
      :annotation          => nil,
      :cpu_sockets         => 1, # wtf
      :memory_mb           => nil,
      :disk_capacity       => nil,
      :bitness             => 64,
      :virtualization_type => "paravirtual",
      :root_device_type    => "ebs"
    )

    expect(@template.hardware.disks.size).to eq(0)
    expect(@template.hardware.guest_devices.size).to eq(0)
    expect(@template.hardware.nics.size).to eq(0)
    expect(@template.hardware.networks.size).to eq(0)
  end

  def assert_specific_template_2
    @template2 = ManageIQ::Providers::Amazon::CloudManager::Template.where(
      :name => "RHEL-7.2_HVM_GA-20151112-x86_64-1-Hourly2-GP2"
    ).first

    # Only graph refresh is able to collect this public template
    unless options.inventory_object_refresh
      expect(@template2).to be_nil
      return
    end

    expect(@template2).to(
      have_attributes(
        :template              => true,
        :ems_ref               => "ami-2051294a",
        :ems_ref_obj           => nil,
        :uid_ems               => "ami-2051294a",
        :vendor                => "amazon",
        :power_state           => "never",
        :publicly_available    => true,
        :location              => "309956199498/RHEL-7.2_HVM_GA-20151112-x86_64-1-Hourly2-GP2",
        :tools_status          => nil,
        :boot_time             => nil,
        :standby_action        => nil,
        :connection_state      => "connected",
        :cpu_affinity          => nil,
        :memory_reserve        => nil,
        :memory_reserve_expand => nil,
        :memory_limit          => nil,
        :memory_shares         => nil,
        :memory_shares_level   => nil,
        :cpu_reserve           => nil,
        :cpu_reserve_expand    => nil,
        :cpu_limit             => nil,
        :cpu_shares            => nil,
        :cpu_shares_level      => nil
      )
    )

    expect(@template2.ext_management_system).to eq(@ems)
    expect(@template2.operating_system).to(
      have_attributes(
        :product_name => "linux_redhat",
      )
    )
    expect(@template2.custom_attributes.size).to eq(0)
    expect(@template2.snapshots.size).to eq(0)

    expect(@template2.hardware).to(
      have_attributes(
        :guest_os            => "linux_redhat",
        :guest_os_full_name  => nil,
        :bios                => nil,
        :annotation          => nil,
        :cpu_sockets         => 1,
        :memory_mb           => nil,
        :disk_capacity       => nil,
        :bitness             => 64,
        :virtualization_type => "hvm",
        :root_device_type    => "ebs"
      )
    )

    expect(@template2.hardware.disks.size).to eq(0)
    expect(@template2.hardware.guest_devices.size).to eq(0)
    expect(@template2.hardware.nics.size).to eq(0)
    expect(@template2.hardware.networks.size).to eq(0)
  end

  def assert_specific_shared_template
    # TODO: Share an EmsRefreshSpec specific template
    t = ManageIQ::Providers::Amazon::CloudManager::Template.where(:ems_ref => "ami-5769193e").first
    expect(t).not_to be_nil
  end

  def assert_specific_cloud_volume_vm_on_cloud_network
    @cloud_volume_vpc = ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume.find_by(
      :name => "EmsRefreshSpecForVpcVm"
    )

    expect(@cloud_volume_vpc).to(
      have_attributes(
        "type"                  => "ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume",
        "ems_ref"               => "vol-0e4c86c12b28cead8",
        "size"                  => 1073741824,
        "ext_management_system" => @ems.ebs_storage_manager,
        "availability_zone"     => @az,
        "name"                  => "EmsRefreshSpecForVpcVm",
        "status"                => "in-use",
        "description"           => nil,
        "volume_type"           => "gp2",
        "bootable"              => nil,
        "cloud_tenant_id"       => nil
      )
    )
  end

  def assert_specific_cloud_volume_vm_on_cloud_network_public_ip
    @cloud_volume_vpc1 = ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume.find_by(
      :name => "EmsRefreshSpecForVpc1"
    )

    expect(@cloud_volume_vpc1).to(
      have_attributes(
        "type"                     => "ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume",
        "ems_ref"                  => "vol-0acad09812d803c09",
        "size"                     => 1073741824,
        "ext_management_system"    => @ems.ebs_storage_manager,
        "availability_zone"        => @az,
        "cloud_volume_snapshot_id" => nil,
        "name"                     => "EmsRefreshSpecForVpc1",
        "status"                   => "in-use",
        "description"              => nil,
        "volume_type"              => "gp2",
        "bootable"                 => nil,
        "cloud_tenant_id"          => nil
      )
    )
  end

  def assert_specific_cloud_volume_snapshot
    based_volume = ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume.find_by(
      :name => "EmsRefreshSpecForVpcVm"
    )

    base_volume = ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume.find_by(
      :name => "EmsRefreshSpecForSnapshot"
    )

    @cloud_volume_snapshot = ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot.find_by(
      :name => "EmsRefreshSpecSnapshot"
    )

    expect(@cloud_volume_snapshot).to(
      have_attributes(
        "type"                  => "ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot",
        "ems_ref"               => "snap-055095f47fab5e749",
        "ext_management_system" => @ems.ebs_storage_manager,
        "cloud_volume"          => base_volume,
        "name"                  => "EmsRefreshSpecSnapshot",
        "description"           => "EmsRefreshSpecSnapshotDesc",
        "status"                => "completed",
        "size"                  => 1073741824,
        "cloud_tenant_id"       => nil
      )
    )

    expect(@cloud_volume_snapshot.based_volumes).to match_array([based_volume])
    expect(based_volume.base_snapshot).to eq(@cloud_volume_snapshot)
    expect(base_volume.cloud_volume_snapshots).to match_array([@cloud_volume_snapshot])
  end

  def assert_specific_cloud_volume_snapshot_encrypted
    base_volume = ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolume.find_by(
      :name => "EmsRefreshSpecForVpc1"
    )

    @cloud_volume_snapshot_encrypted = ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot.find_by(
      :name => "EmsRefreshSpecSnapshotOfVpc1"
    )

    expect(@cloud_volume_snapshot_encrypted).to(
      have_attributes(
        "type"                  => "ManageIQ::Providers::Amazon::StorageManager::Ebs::CloudVolumeSnapshot",
        "ems_ref"               => "snap-0c78ca2afaa671102",
        "ext_management_system" => @ems.ebs_storage_manager,
        "cloud_volume"          => base_volume,
        "name"                  => "EmsRefreshSpecSnapshotOfVpc1",
        "description"           => "EmsRefreshSpecSnapshotOfVpc1Desc",
        "status"                => "completed",
        "size"                  => 1073741824,
        "cloud_tenant_id"       => nil
      )
    )

    expect(base_volume.cloud_volume_snapshots).to match_array([@cloud_volume_snapshot_encrypted])
  end

  def assert_specific_vm_powered_on
    assert_specific_floating_ip

    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(
      :name            => "EmsRefreshSpec-PoweredOn-Basic3",
      :raw_power_state => "running"
    ).first
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "i-680071e9",
      :ems_ref_obj           => nil,
      :uid_ems               => "i-680071e9",
      :vendor                => "amazon",
      :power_state           => "on",
      :location              => "ec2-54-221-202-53.compute-1.amazonaws.com",
      :tools_status          => nil,
      :boot_time             => Time.zone.parse("2017-09-07 14:42:55.000000000 +0000"),
      :standby_action        => nil,
      :connection_state      => "connected",
      :cpu_affinity          => nil,
      :memory_reserve        => nil,
      :memory_reserve_expand => nil,
      :memory_limit          => nil,
      :memory_shares         => nil,
      :memory_shares_level   => nil,
      :cpu_reserve           => nil,
      :cpu_reserve_expand    => nil,
      :cpu_limit             => nil,
      :cpu_shares            => nil,
      :cpu_shares_level      => nil,
    )

    expect(v.ext_management_system).to eq(@ems)
    expect(v.availability_zone).to eq(@az)
    expect(v.floating_ip).to eq(@ip)
    expect(v.network_ports.first.floating_ips.count).to eq(1)
    expect(v.network_ports.first.floating_ips).to match_array([@ip])
    expect(v.network_ports.first.floating_ip_addresses).to match_array([@ip.address])
    expect(v.network_ports.first.fixed_ip_addresses).to match_array([@ip.fixed_ip_address])
    expect(v.network_ports.first.ipaddresses).to match_array([@ip.fixed_ip_address, @ip.address])
    expect(v.ipaddresses).to match_array([@ip.fixed_ip_address, @ip.address])
    expect(v.flavor).to eq(@flavor)
    expect(v.key_pairs).to match_array([@kp])
    expect(v.cloud_network).to     be_nil
    expect(v.cloud_subnet).to      be_nil
    sg_2 = ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup
           .where(:name => "EmsRefreshSpec-SecurityGroup2").first
    expect(v.security_groups)
      .to match_array [sg_2, @sg]

    expect(v.operating_system).to(
      have_attributes(
        :product_name => "linux_generic",
      )
    )
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :guest_os            => "linux_generic",
      :guest_os_full_name  => nil,
      :bios                => nil,
      :annotation          => nil,
      :cpu_sockets         => 1,
      :memory_mb           => 627,
      :disk_capacity       => 0, # TODO: Change to a flavor that has disks
      :bitness             => 64,
      :virtualization_type => "paravirtual"
    )

    expect(v.hardware.disks.size).to eq(1) # TODO: Change to a flavor that has disks
    expect(v.cloud_volumes.pluck(:name, :volume_type)).to match_array([["EmsRefreshSpec-PoweredOn-Basic3-root", "standard"]])
    expect(v.hardware.guest_devices.size).to eq(0)
    expect(v.hardware.nics.size).to eq(0)

    expect(v.hardware.networks.size).to eq(2)
    network = v.hardware.networks.where(:description => "public").first
    expect(network).to have_attributes(
      :description => "public",
      :ipaddress   => @ip.address,
      :hostname    => "ec2-54-221-202-53.compute-1.amazonaws.com"
    )
    network = v.hardware.networks.where(:description => "private").first
    expect(network).to have_attributes(
      :description => "private",
      :ipaddress   => "10.91.143.248",
      :hostname    => "ip-10-91-143-248.ec2.internal"
    )

    expect(v.load_balancers.collect(&:name)).to match_array ["EmsRefreshSpec-LoadBalancer"]
    expect(v.load_balancer_health_checks.collect(&:ems_ref)).to match_array ["EmsRefreshSpec-LoadBalancer"]
    expect(v.load_balancer_listeners.collect(&:ems_ref)).to match_array ["EmsRefreshSpec-LoadBalancer__HTTP__80__HTTP__80__"]
    expect(v.load_balancer_health_check_states).to match_array ["OutOfService"]
    healt_check_states_with_reason = [
      "Status: OutOfService, Status Reason: Instance has failed at least the UnhealthyThreshold number of health checks consecutively."
    ]
    expect(v.load_balancer_health_check_states_with_reason).to match_array healt_check_states_with_reason

    v.with_relationship_type("genealogy") do
      expect(v.parent).to eq(@template)
    end
    expect(v.custom_attributes.size).to eq(2)
    expect(v.custom_attributes.find_by(:name => "Name").value).to eq("EmsRefreshSpec-PoweredOn-Basic3")
    expect(v.custom_attributes.find_by(:name => "owner").value).to eq("UNKNOWN")
    assert_mapped_tags_on_vm(v, :owner => "UNKNOWN")
  end

  def assert_specific_vm_powered_off
    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(
      :name            => "EmsRefreshSpec-PoweredOff",
      :raw_power_state => "stopped"
    ).first
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "i-0e1752ff841801f65",
      :ems_ref_obj           => nil,
      :uid_ems               => "i-0e1752ff841801f65",
      :vendor                => "amazon",
      :power_state           => "off",
      :location              => "unknown",
      :tools_status          => nil,
      :boot_time             => Time.zone.parse("2018-09-03 12:10:36.000000000 +0000"),
      :standby_action        => nil,
      :connection_state      => "connected",
      :cpu_affinity          => nil,
      :memory_reserve        => nil,
      :memory_reserve_expand => nil,
      :memory_limit          => nil,
      :memory_shares         => nil,
      :memory_shares_level   => nil,
      :cpu_reserve           => nil,
      :cpu_reserve_expand    => nil,
      :cpu_limit             => nil,
      :cpu_shares            => nil,
      :cpu_shares_level      => nil
    )

    expect(v.ext_management_system).to eq(@ems)
    expect(v.availability_zone)
      .to eq(ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.find_by(:name => "us-east-1e"))
    expect(v.floating_ip).to be_nil
    expect(v.key_pairs).to match_array([@kp])
    expect(v.cloud_network).to be_nil
    expect(v.cloud_subnet).to be_nil
    sg_2 = ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup
           .where(:name => "EmsRefreshSpec-SecurityGroup2").first
    expect(v.security_groups)
      .to match_array [sg_2, @sg]
    expect(v.operating_system).to(
      have_attributes(
        :product_name => "linux_generic",
      )
    )
    expect(v.custom_attributes.size).to eq(2)
    expect(v.custom_attributes.find_by(:name => "Name").value).to eq("EmsRefreshSpec-PoweredOff")
    expect(v.custom_attributes.find_by(:name => "owner").value).to eq("UNKNOWN")
    assert_mapped_tags_on_vm(v, :owner => "UNKNOWN")
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :config_version       => nil,
      :virtual_hw_version   => nil,
      :guest_os             => "linux_generic",
      :cpu_sockets          => 1,
      :bios                 => nil,
      :bios_location        => nil,
      :time_sync            => nil,
      :annotation           => nil,
      :memory_mb            => 627,
      :host_id              => nil,
      :cpu_speed            => nil,
      :cpu_type             => nil,
      :size_on_disk         => nil,
      :manufacturer         => "",
      :model                => "",
      :number_of_nics       => nil,
      :cpu_usage            => nil,
      :memory_usage         => nil,
      :cpu_cores_per_socket => 1,
      :cpu_total_cores      => 1,
      :vmotion_enabled      => nil,
      :disk_free_space      => nil,
      :disk_capacity        => 0,
      :guest_os_full_name   => nil,
      :memory_console       => nil,
      :bitness              => 64,
      :virtualization_type  => "paravirtual",
      :root_device_type     => "ebs",
    )

    expect(v.hardware.disks.size).to eq(1) # TODO: Change to a flavor that has disks
    expect(v.cloud_volumes.pluck(:name, :volume_type)).to match_array([["vol-076672a9b80ac2e25", "gp2"]])
    expect(v.hardware.guest_devices.size).to eq(0)
    expect(v.hardware.nics.size).to eq(0)
    expect(v.hardware.networks.size).to eq(0)

    v.with_relationship_type("genealogy") do
      expect(v.parent).to eq(@template)
    end
  end

  def assert_specific_vm_on_cloud_network
    assert_specific_floating_ip_for_cloud_network

    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(:name => "EmsRefreshSpec-PoweredOn-VPC").first
    expect(v).to(
      have_attributes(
        :template              => false,
        :ems_ref               => "i-8b5739f2",
        :ems_ref_obj           => nil,
        :uid_ems               => "i-8b5739f2",
        :vendor                => "amazon",
        :power_state           => "on",
        :location              => "unknown",
        :tools_status          => nil,
        :boot_time             => Time.zone.parse("2017-09-13 16:07:19.000000000 +0000"),
        :standby_action        => nil,
        :connection_state      => "connected",
        :cpu_affinity          => nil,
        :memory_reserve        => nil,
        :memory_reserve_expand => nil,
        :memory_limit          => nil,
        :memory_shares         => nil,
        :memory_shares_level   => nil,
        :cpu_reserve           => nil,
        :cpu_reserve_expand    => nil,
        :cpu_limit             => nil,
        :cpu_shares            => nil,
        :cpu_shares_level      => nil
      )
    )

    expect(v.cloud_networks.first).to eq(@cn)
    expect(v.cloud_subnets.first).to eq(@subnet)
    expect(v.security_groups).to match_array([@sg_on_cn])
    expect(v.floating_ip).to eq(@ip1)
    expect(v.floating_ips).to match_array([@ip1])
    expect(v.network_ports.first.floating_ips.count).to eq(1)
    expect(v.network_ports.first.floating_ips).to match_array([@ip1])
    expect(v.network_ports.first.floating_ip_addresses).to match_array([@ip1.address])
    expect(v.network_ports.first.fixed_ip_addresses).to match_array([@ip1.fixed_ip_address, '10.0.0.208'])
    expect(v.network_ports.first.ipaddresses).to match_array([@ip1.fixed_ip_address, '10.0.0.208', @ip1.address])
    expect(v.ipaddresses).to match_array([@ip1.fixed_ip_address, '10.0.0.208', @ip1.address])

    expect(v.load_balancers.collect(&:name)).to match_array %w(EmSRefreshSpecVPCELB EmSRefreshSpecVPCELB2)
    expect(v.load_balancer_health_checks.collect(&:ems_ref)).to match_array %w(EmSRefreshSpecVPCELB
                                                                               EmSRefreshSpecVPCELB2)
    listeners = %w(
      EmSRefreshSpecVPCELB2__TCP__2222__TCP__22__
      EmSRefreshSpecVPCELB__HTTP__80__HTTP__80__
      EmSRefreshSpecVPCELB__TCP__22__TCP__22__
    )
    expect(v.load_balancer_listeners.collect(&:ems_ref)).to match_array listeners
    expect(v.load_balancer_health_check_states).to match_array %w(OutOfService OutOfService)
    healt_check_states_with_reason = [
      "Status: OutOfService, Status Reason: Instance has failed at least the UnhealthyThreshold number of health checks consecutively.",
      "Status: OutOfService, Status Reason: Instance has failed at least the UnhealthyThreshold number of health checks consecutively."
    ]
    expect(v.load_balancer_health_check_states_with_reason).to match_array healt_check_states_with_reason

    expect(v.operating_system).to(
      have_attributes(
        :product_name => "linux_generic",
      )
    )
    expect(v.custom_attributes.size).to eq(2)
    expect(v.custom_attributes.find_by(:name => "Name").value).to eq("EmsRefreshSpec-PoweredOn-VPC")
    expect(v.custom_attributes.find_by(:name => "owner").value).to eq("UNKNOWN")
    assert_mapped_tags_on_vm(v, :owner => "UNKNOWN")
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to(
      have_attributes(
        :config_version       => nil,
        :virtual_hw_version   => nil,
        :guest_os             => "linux_generic",
        :cpu_sockets          => 1,
        :bios                 => nil,
        :bios_location        => nil,
        :time_sync            => nil,
        :annotation           => nil,
        :memory_mb            => 627,
        :host_id              => nil,
        :cpu_speed            => nil,
        :cpu_type             => nil,
        :size_on_disk         => nil,
        :manufacturer         => "",
        :model                => "",
        :number_of_nics       => nil,
        :cpu_usage            => nil,
        :memory_usage         => nil,
        :cpu_cores_per_socket => 1,
        :cpu_total_cores      => 1,
        :vmotion_enabled      => nil,
        :disk_free_space      => nil,
        :disk_capacity        => 0,
        :guest_os_full_name   => nil,
        :memory_console       => nil,
        :bitness              => 64,
        :virtualization_type  => "paravirtual",
        :root_device_type     => "ebs",
      )
    )

    expect(v.hardware.disks.size).to eq(2) # TODO: Change to a flavor that has disks

    expect(v.hardware.disks.detect { |x| x.device_name == "sda1" }).to(
      have_attributes(
        :device_name        => "sda1",
        :device_type        => "disk",
        :location           => "sda1",
        :filename           => nil,
        :hardware           => v.hardware,
        :mode               => nil,
        :controller_type    => "amazon",
        :size               => 7516192768,
        :free_space         => nil,
        :size_on_disk       => nil,
        :present            => true,
        :start_connected    => true,
        :auto_detect        => nil,
        :disk_type          => nil,
        :storage_id         => nil,
        :backing_type       => "CloudVolume",
        :storage_profile_id => nil,
        :bootable           => nil,
      )
    )

    expect(v.hardware.disks.detect { |x| x.device_name == "sdf" }).to(
      have_attributes(
        :device_name        => "sdf",
        :device_type        => "disk",
        :location           => "sdf",
        :filename           => nil,
        :hardware           => v.hardware,
        :mode               => nil,
        :controller_type    => "amazon",
        :size               => 1073741824,
        :free_space         => nil,
        :size_on_disk       => nil,
        :present            => true,
        :start_connected    => true,
        :auto_detect        => nil,
        :disk_type          => nil,
        :storage_id         => nil,
        :backing            => @cloud_volume_vpc,
        :backing_type       => "CloudVolume",
        :storage_profile_id => nil,
        :bootable           => nil,
      )
    )

    expect(v.hardware.disks.size).to eq(2) # TODO: Change to a flavor that has disks
    expect(v.cloud_volumes.pluck(:name, :volume_type)).to(
      match_array([["EmsRefreshSpec-PoweredOn-VPC-root", "standard"], ["EmsRefreshSpecForVpcVm", "gp2"]])
    )
    expect(v.hardware.guest_devices.size).to eq(0)
    expect(v.hardware.nics.size).to eq(0)
    expect(v.hardware.networks.size).to eq(2)

    v.with_relationship_type("genealogy") do
      expect(v.parent).to eq(@template)
    end
  end

  def assert_specific_vm_on_cloud_network_public_ip
    assert_specific_public_ip_for_cloud_network

    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(:name => "EmsRefreshSpec-PoweredOn-VPC1").first
    expect(v).to(
      have_attributes(
        :template              => false,
        :ems_ref               => "i-c72af2f6",
        :ems_ref_obj           => nil,
        :uid_ems               => "i-c72af2f6",
        :vendor                => "amazon",
        :power_state           => "on",
        :location              => "unknown",
        :tools_status          => nil,
        :boot_time             => Time.zone.parse("2017-09-26 07:43:04.000000000 +0000"),
        :standby_action        => nil,
        :connection_state      => "connected",
        :cpu_affinity          => nil,
        :memory_reserve        => nil,
        :memory_reserve_expand => nil,
        :memory_limit          => nil,
        :memory_shares         => nil,
        :memory_shares_level   => nil,
        :cpu_reserve           => nil,
        :cpu_reserve_expand    => nil,
        :cpu_limit             => nil,
        :cpu_shares            => nil,
        :cpu_shares_level      => nil
      )
    )

    expect(v.cloud_networks.first).to eq(@cn)
    expect(v.cloud_subnets.first).to eq(@subnet)
    expect(v.security_groups).to match_array([@sg_on_cn])
    expect(v.floating_ip).to eq(@ip2)
    expect(v.floating_ips).to match_array([@ip2])
    expect(v.network_ports.first.floating_ips.count).to eq(1)
    expect(v.network_ports.first.floating_ips).to match_array([@ip2])
    expect(v.network_ports.first.floating_ip_addresses).to match_array([@ip2.address])
    expect(v.network_ports.first.fixed_ip_addresses).to match_array([@ip2.fixed_ip_address])
    expect(v.network_ports.first.ipaddresses).to match_array([@ip2.fixed_ip_address, @ip2.address])
    expect(v.ipaddresses).to match_array([@ip2.fixed_ip_address, @ip2.address])

    if options.inventory_object_refresh
      expect(v.operating_system).to(
        have_attributes(
          :product_name => "linux_redhat",
        )
      )
    else
      # Old refresh can't fetch the public image and there fore also operating_system
      expect(v.operating_system).to be_nil
    end

    expect(v.custom_attributes.size).to eq(2)
    expect(v.custom_attributes.find_by(:name => "Name").value).to eq("EmsRefreshSpec-PoweredOn-VPC1")
    expect(v.custom_attributes.find_by(:name => "owner").value).to eq("UNKNOWN")
    assert_mapped_tags_on_vm(v, :owner => "UNKNOWN")
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to(
      have_attributes(
        :config_version       => nil,
        :virtual_hw_version   => nil,
        :guest_os             => options.inventory_object_refresh ? "linux_redhat" : nil,
        :cpu_sockets          => 1,
        :bios                 => nil,
        :bios_location        => nil,
        :time_sync            => nil,
        :annotation           => nil,
        :memory_mb            => 1024,
        :host_id              => nil,
        :cpu_speed            => nil,
        :cpu_type             => nil,
        :size_on_disk         => nil,
        :manufacturer         => "",
        :model                => "",
        :number_of_nics       => nil,
        :cpu_usage            => nil,
        :memory_usage         => nil,
        :cpu_cores_per_socket => 1,
        :cpu_total_cores      => 1,
        :vmotion_enabled      => nil,
        :disk_free_space      => nil,
        :disk_capacity        => 0,
        :guest_os_full_name   => nil,
        :memory_console       => nil,
        :bitness              => 64,
        :virtualization_type  => "hvm",
        :root_device_type     => "ebs",
      )
    )

    expect(v.hardware.disks.size).to eq(2) # TODO: Change to a flavor that has disks

    expect(v.hardware.disks.detect { |x| x.device_name == "sda1" }).to(
      have_attributes(
        :device_name        => "sda1",
        :device_type        => "disk",
        :location           => "sda1",
        :filename           => nil,
        :hardware           => v.hardware,
        :mode               => nil,
        :controller_type    => "amazon",
        :size               => 10737418240,
        :free_space         => nil,
        :size_on_disk       => nil,
        :present            => true,
        :start_connected    => true,
        :auto_detect        => nil,
        :disk_type          => nil,
        :storage_id         => nil,
        :backing_type       => "CloudVolume",
        :storage_profile_id => nil,
        :bootable           => nil,
      )
    )

    expect(v.hardware.disks.detect { |x| x.device_name == "sdf" }).to(
      have_attributes(
        :device_name        => "sdf",
        :device_type        => "disk",
        :location           => "sdf",
        :filename           => nil,
        :hardware           => v.hardware,
        :mode               => nil,
        :controller_type    => "amazon",
        :size               => 1073741824,
        :free_space         => nil,
        :size_on_disk       => nil,
        :present            => true,
        :start_connected    => true,
        :auto_detect        => nil,
        :disk_type          => nil,
        :storage_id         => nil,
        :backing            => @cloud_volume_vpc1,
        :backing_type       => "CloudVolume",
        :storage_profile_id => nil,
        :bootable           => nil,
      )
    )

    expect(v.cloud_volumes.pluck(:name, :volume_type)).to(
      match_array([["EmsRefreshSpec-PoweredOn-VPC1-root", "gp2"], ["EmsRefreshSpecForVpc1", "gp2"]])
    )
    expect(v.hardware.guest_devices.size).to eq(0)
    expect(v.hardware.nics.size).to eq(0)
    expect(v.hardware.networks.size).to eq(2)

    v.with_relationship_type("genealogy") do
      expect(v.parent).to eq(@template2)
    end
  end

  def assert_specific_load_balancer_non_vpc
    @elb_non_vpc = ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer.where(
      :name => "EmsRefreshSpec-LoadBalancer"
    ).first
    expect(@elb_non_vpc).to have_attributes(
      "ems_ref"         => "EmsRefreshSpec-LoadBalancer",
      "name"            => "EmsRefreshSpec-LoadBalancer",
      "description"     => nil,
      "cloud_tenant_id" => nil,
      "type"            => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer"
    )

    expect(@elb_non_vpc.ext_management_system).to eq(@ems.network_manager)
    expect(@elb_non_vpc.load_balancer_pool_members.count).to eq 1
  end

  def assert_specific_load_balancer_non_vpc_vms
    expect(@elb_non_vpc.vms.first.name).to eq "EmsRefreshSpec-PoweredOn-Basic3"
  end

  def assert_specific_load_balancer_vpc
    @elb = ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer.where(
      :name => "EmSRefreshSpecVPCELB"
    ).first
    expect(@elb).to have_attributes(
      "ems_ref"         => "EmSRefreshSpecVPCELB",
      "name"            => "EmSRefreshSpecVPCELB",
      "description"     => nil,
      "cloud_tenant_id" => nil,
      "type"            => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer"
    )

    expect(@elb.ext_management_system).to eq(@ems.network_manager)
    expect(@elb.network_ports.map(&:name)).to(match_array("EmSRefreshSpecVPCELB"))
    expect(@elb.floating_ips.map(&:address)).to(
      match_array(
        ["EmSRefreshSpecVPCELB-546141344.us-east-1.elb.amazonaws.com"]
      )
    )
  end

  def assert_specific_load_balancer_vpc_relations
    expect(@elb.vms.count).to eq 1
    expect(@elb.load_balancer_pool_members.count).to eq 1
    expect(@elb.load_balancer_pool_members.first.ext_management_system).to eq @ems.network_manager
    expect(@elb.vms.first.ext_management_system).to eq @ems
    expect(@elb.vms.collect(&:name)).to match_array ["EmsRefreshSpec-PoweredOn-VPC"]
    expect(@elb.cloud_subnets.map(&:name)).to(match_array(["EmsRefreshSpec-Subnet1", "EmsRefreshSpec-Subnet2"]))
  end

  def assert_specific_load_balancer_vpc_and_vpc2_relations
    expect(@elb.vms).to match_array @elb2.vms
    expect(@elb.load_balancer_pool_members).to match_array @elb2.load_balancer_pool_members
  end

  def assert_specific_load_balancer_vpc2
    @elb2 = ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer.where(
      :name => "EmSRefreshSpecVPCELB2"
    ).first
    expect(@elb2).to have_attributes(
      "ems_ref"         => "EmSRefreshSpecVPCELB2",
      "name"            => "EmSRefreshSpecVPCELB2",
      "description"     => nil,
      "cloud_tenant_id" => nil,
      "type"            => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer"
    )

    expect(@elb2.ext_management_system).to eq(@ems.network_manager)
  end

  def assert_specific_load_balancers
    assert_specific_load_balancer_non_vpc
    assert_specific_load_balancer_non_vpc_vms
    assert_specific_load_balancer_vpc
    assert_specific_load_balancer_vpc_relations
    assert_specific_load_balancer_vpc2
    assert_specific_load_balancer_vpc_and_vpc2_relations
  end

  def assert_specific_load_balancer_listeners_non_vpc
    expect(@elb_non_vpc.load_balancer_listeners.count).to eq 1

    @listener_non_vpc = @elb_non_vpc.load_balancer_listeners
                                    .where(:ems_ref => "EmsRefreshSpec-LoadBalancer__HTTP__80__HTTP__80__").first
    expect(@listener_non_vpc).to have_attributes(
      "ems_ref"                  => "EmsRefreshSpec-LoadBalancer__HTTP__80__HTTP__80__",
      "name"                     => nil,
      "description"              => nil,
      "load_balancer_protocol"   => "HTTP",
      "load_balancer_port_range" => 80...81,
      "instance_protocol"        => "HTTP",
      "instance_port_range"      => 80...81,
      "cloud_tenant_id"          => nil,
      "type"                     => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener"
    )
    expect(@listener_non_vpc.ext_management_system).to eq(@ems.network_manager)
  end

  def assert_specific_load_balancer_listeners_vpc_and_vpc_2
    expect(@elb.load_balancer_listeners.count).to eq 2
    expect(@elb2.load_balancer_listeners.count).to eq 1

    listener_1 = @elb.load_balancer_listeners
                     .where(:ems_ref => "EmSRefreshSpecVPCELB__TCP__22__TCP__22__").first
    expect(listener_1).to have_attributes(
      "ems_ref"                  => "EmSRefreshSpecVPCELB__TCP__22__TCP__22__",
      "name"                     => nil,
      "description"              => nil,
      "load_balancer_protocol"   => "TCP",
      "load_balancer_port_range" => 22...23,
      "instance_protocol"        => "TCP",
      "instance_port_range"      => 22...23,
      "cloud_tenant_id"          => nil,
      "type"                     => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener"
    )
    expect(listener_1.ext_management_system).to eq(@ems.network_manager)

    @listener_2 = @elb.load_balancer_listeners
                      .where(:ems_ref => "EmSRefreshSpecVPCELB__HTTP__80__HTTP__80__").first
    expect(@listener_2).to have_attributes(
      "ems_ref"                  => "EmSRefreshSpecVPCELB__HTTP__80__HTTP__80__",
      "name"                     => nil,
      "description"              => nil,
      "load_balancer_protocol"   => "HTTP",
      "load_balancer_port_range" => 80...81,
      "instance_protocol"        => "HTTP",
      "instance_port_range"      => 80...81,
      "cloud_tenant_id"          => nil,
      "type"                     => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener"
    )
    expect(@listener_2.ext_management_system).to eq(@ems.network_manager)
    expect(@listener_2.load_balancer_pools.count).to eq 1
    expect(@listener_2.load_balancer_pools.first.type).to(
      eq("ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPool")
    )

    @listener_3 = @elb2.load_balancer_listeners.first
    expect(@listener_3).to have_attributes(
      "ems_ref"                  => "EmSRefreshSpecVPCELB2__TCP__2222__TCP__22__",
      "name"                     => nil,
      "description"              => nil,
      "load_balancer_protocol"   => "TCP",
      "load_balancer_port_range" => 2222...2223,
      "instance_protocol"        => "TCP",
      "instance_port_range"      => 22...23,
      "cloud_tenant_id"          => nil,
      "type"                     => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener"
    )
    expect(@listener_3.ext_management_system).to eq(@ems.network_manager)
  end

  def assert_specific_load_balancer_listeners
    assert_specific_load_balancer_listeners_non_vpc
    assert_specific_load_balancer_listeners_vpc_and_vpc_2
  end

  def assert_specific_load_balancer_health_checks_non_vpc
    expect(@elb_non_vpc.load_balancer_health_checks.count).to eq 1

    health_check_non_vpc = @elb_non_vpc.load_balancer_health_checks.first
    expect(health_check_non_vpc).to have_attributes(
      "ems_ref"             => "EmsRefreshSpec-LoadBalancer",
      "name"                => nil,
      "protocol"            => "TCP",
      "port"                => 22,
      "url_path"            => "",
      "interval"            => 30,
      "timeout"             => 5,
      "healthy_threshold"   => 10,
      "unhealthy_threshold" => 2,
      "cloud_tenant_id"     => nil,
      "type"                => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerHealthCheck"
    )

    expect(health_check_non_vpc.load_balancer_listener).to eq nil
  end

  def assert_specific_load_balancer_health_checks_vpc_and_vpc_2
    expect(@elb.load_balancer_health_checks.count).to eq 1

    health_check_1 = @elb.load_balancer_health_checks.first
    expect(health_check_1).to have_attributes(
      "ems_ref"             => "EmSRefreshSpecVPCELB",
      "name"                => nil,
      "protocol"            => "HTTP",
      "port"                => 80,
      "url_path"            => "index.html",
      "interval"            => 30,
      "timeout"             => 5,
      "healthy_threshold"   => 10,
      "unhealthy_threshold" => 2,
      "cloud_tenant_id"     => nil,
      "type"                => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerHealthCheck"
    )

    expect(@elb2.load_balancer_health_checks.count).to eq 1

    health_check_2 = @elb2.load_balancer_health_checks.first
    expect(health_check_2).to have_attributes(
      "ems_ref"             => "EmSRefreshSpecVPCELB2",
      "name"                => nil,
      "protocol"            => "TCP",
      "port"                => 22,
      "url_path"            => "",
      "interval"            => 30,
      "timeout"             => 5,
      "healthy_threshold"   => 10,
      "unhealthy_threshold" => 2,
      "cloud_tenant_id"     => nil,
      "type"                => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerHealthCheck"
    )

    expect(health_check_1.load_balancer_pool_members.count).to eq 1
    expect(health_check_1.load_balancer_pool_members).to match_array health_check_2.load_balancer_pool_members

    expect(health_check_1.load_balancer_pool_members.collect(&:type)).to(
      match_array(
        ["ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerPoolMember"] * 1
      )
    )
    expect(health_check_1.vms).to match_array health_check_2.vms
  end

  def assert_specific_load_balancer_health_checks
    assert_specific_load_balancer_health_checks_non_vpc
    assert_specific_load_balancer_health_checks_vpc_and_vpc_2
  end

  def assert_specific_orchestration_template
    @orch_template = ::ManageIQ::Providers::Amazon::CloudManager::OrchestrationTemplate.where(:md5 => "d986d851f5413fddcf1366914fbb2d28").first
    expect(@orch_template.description).to start_with("AWS CloudFormation Sample Template VPC_Single_Instance_In_Subnet")
    expect(@orch_template.content).to start_with("{\n  \"AWSTemplateFormatVersion\" : \"2010-09-09\",")
    expect(@orch_template).to have_attributes(:draft => false, :orderable => false)
  end

  def assert_specific_orchestration_stack
    assert_specific_parent_orchestration_stack_data
    assert_specific_orchestration_stack_data
    assert_specific_orchestration_stack_parameters
    assert_specific_orchestration_stack_resources
    assert_specific_orchestration_stack_outputs
    assert_specific_orchestration_stack_associations
  end

  def assert_specific_parent_orchestration_stack_data
    @parent_stack = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack.find_by(
      :name => "EmsRefreshSpecStack"
    )

    expect(@parent_stack).to(
      have_attributes(
        :status_reason => nil,
        :status        => "CREATE_COMPLETE",
        :ems_ref       => "arn:aws:cloudformation:us-east-1:200278856672:stack/EmsRefreshSpecStack/"\
                          "b4e06950-2fed-11e7-bd93-500c286374d1",
      )
    )

    expect(@parent_stack.description).to start_with("AWS CloudFormation Sample Template vpc_single_instance_in_subnet")
  end

  def assert_specific_orchestration_stack_data
    @orch_stack = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack.find_by(
      :name => "EmsRefreshSpecStack-WebServerInstance-1CTHQS2P5WJ7S"
    )
    expect(@orch_stack).to(
      have_attributes(
        :status_reason => nil,
        :status        => "CREATE_COMPLETE",
        :ems_ref       => "arn:aws:cloudformation:us-east-1:200278856672:stack/EmsRefreshSpecStack-"\
                          "WebServerInstance-1CTHQS2P5WJ7S/d3bb46b0-2fed-11e7-a3d9-503f23fb55fe",
      )
    )

    expect(@orch_stack.description).to start_with("AWS CloudFormation Sample Template VPC_Single_Instance_In_Subnet")
  end

  def assert_specific_orchestration_stack_parameters
    parameters = @orch_stack.parameters.order("ems_ref")
    expect(parameters.size).to eq(6)

    # assert one of the parameter models
    expect(parameters.map { |x| x.attributes.select { |k, _v| %w(name value).include?(k) } }).to(
      match_array(
        [
          {"name" => "DBRootPassword", "value" => "****"},
          {"name" => "InstanceSecurityGroupID", "value" => "sg-76c10f08"},
          {"name" => "InstanceType", "value" => "t2.nano"},
          {"name" => "KeyName", "value" => "EmsRefreshSpec-KeyPair"},
          {"name" => "SSHLocation", "value" => "0.0.0.0/0"},
          {"name" => "SubnetID", "value" => "subnet-2190b144"}
        ]
      )
    )
  end

  def assert_specific_orchestration_stack_resources
    resources = @orch_stack.resources.order("ems_ref")
    expect(resources.size).to eq(2)

    # assert one of the resource models
    fields_to_compare = %w(name logical_resource physical_resource resource_category resource_status resource_status_reason)
    expect(resources.map { |x| x.attributes.select { |k, _v| fields_to_compare.include?(k) } }).to(
      match_array(
        [
          {
            "name"                   => "IPAddress",
            "logical_resource"       => "IPAddress",
            "physical_resource"      => "34.202.178.10",
            "resource_category"      => "AWS::EC2::EIP",
            "resource_status"        => "CREATE_COMPLETE",
            "resource_status_reason" => nil
          }, {
            "name"                   => "WebServerInstance",
            "logical_resource"       => "WebServerInstance",
            "physical_resource"      => "i-0bca58e6e540ddc39",
            "resource_category"      => "AWS::EC2::Instance",
            "resource_status"        => "CREATE_COMPLETE",
            "resource_status_reason" => nil
          }
        ]
      )
    )
  end

  def assert_specific_orchestration_stack_outputs
    outputs = @orch_stack.outputs
    expect(outputs.size).to eq(1)
    expect(outputs.map { |x| x.attributes.select { |k, _v| %w(key value description).include?(k) } }).to(
      match_array(
        [
          {"key"         => "URL",
           "value"       => "http://34.202.178.10",
           "description" => "Newly created application URL"}
        ]
      )
    )
  end

  def assert_specific_orchestration_stack_associations
    @orch_stack_vm = Vm.where(:ems_ref => "i-0bca58e6e540ddc39").first
    @orch_stack_floating_ip = @orch_stack_vm.floating_ips.first
    @parent_stack_sg = @orch_stack_vm.security_groups.first
    @parent_stack_vpc = @orch_stack_vm.cloud_networks.first
    @orch_stack_floating_ip = @orch_stack_vm.cloud_networks.first

    expect(@parent_stack_sg).not_to be_nil
    expect(@parent_stack_vpc).not_to be_nil
    expect(@orch_stack_floating_ip).not_to be_nil

    # orchestration stack belongs to a provider
    expect(@orch_stack.ext_management_system).to eq(@ems)

    # orchestration stack belongs to an orchestration template
    expect(@orch_stack.orchestration_template).to eq(@orch_template)

    # orchestration stack can be nested
    expect(@orch_stack.parent).to eq(@parent_stack)
    expect(@parent_stack.children).to match_array([@orch_stack])

    # orchestration stack can have vms
    expect(@orch_stack_vm.orchestration_stack).to eq(@orch_stack)
    expect(@orch_stack.vms).to match_array([@orch_stack_vm])

    # Check parent stack relations
    # orchestration stack can have vms
    expect(@parent_stack.vms).to match_array([@orch_stack_vm])

    # orchestration stack can have security groups
    expect(@parent_stack_sg.orchestration_stack).to eq(@parent_stack)

    # orchestration stack can have cloud networks
    expect(@parent_stack_vpc.orchestration_stack).to eq(@parent_stack)
  end

  def assert_network_router
    return unless options.inventory_object_refresh # we collect NetworkRouter only in new refresh

    @network_router = ManageIQ::Providers::Amazon::NetworkManager::NetworkRouter.find_by(
      :name => "EmsRefreshSpecRouter"
    )

    expect(@network_router).to(
      have_attributes(
        :propagating_vgws => [],
        :main_route_table => false,
        :status           => "active"
      )
    )

    expect(@network_router.routes).to(
      match_array(
        [
          {
            "destination_cidr_block" => "10.0.0.0/16",
            "gateway_id"             => "local",
            "origin"                 => "CreateRouteTable",
            "state"                  => "active"
          }, {
            "destination_cidr_block" => "0.0.0.0/0",
            "gateway_id"             => "igw-fe49ff90",
            "origin"                 => "CreateRoute",
            "state"                  => "active"
          }
        ]
      )
    )

    expect(@network_router.cloud_subnets.pluck(:name)).to include("EmsRefreshSpec-Subnet1")
    expect(@network_router.vms.pluck(:name)).to include("EmsRefreshSpec-PoweredOn-VPC")
    expect(@network_router.vms.pluck(:name)).to include("EmsRefreshSpec-PoweredOn-VPC1")
  end

  def assert_specific_vm_in_other_region
    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(:name => "EmsRefreshSpec-PoweredOn-OtherRegion").first
    expect(v).to be_nil
  end

  def assert_relationship_tree
    expect(@ems.descendants_arranged).to match_relationship_tree({})
  end

  def assert_specific_labels_on_vm
    vm = ManageIQ::Providers::Amazon::CloudManager::Vm.find_by(:name => "EmsRefreshSpec-PoweredOn-Basic3")
    expect(vm.labels).to include(
      an_object_having_attributes(
        :name   => "owner",
        :value  => "UNKNOWN",
        :source => "amazon"
      )
    )
  end

  def create_tag_mapping
    @all_tag_mapping = FactoryBot.create(:tag_mapping_with_category,
                                          :label_name => "owner")
    @all_tag_mapping_category = @all_tag_mapping.tag.classification

    @image_tag_mapping = FactoryBot.create(:tag_mapping_with_category,
                                            :label_name => "Name", :labeled_resource_type => "Image")
    @image_tag_mapping_category = @image_tag_mapping.tag.classification
  end

  # Tests can assert this if they called create_tag_mapping before refresh.
  def assert_mapped_tags_on_vm(vm, owner:)
    expect(@all_tag_mapping_category.children.collect(&:description)).to include(owner)

    expect(vm.tags.count).to eq(1)
    expect(vm.tags.first.category).to eq(@all_tag_mapping_category)
    expect(vm.tags.first.classification.description).to eq("UNKNOWN")
  end

  # Tests can assert this if they called create_tag_mapping before refresh.
  def assert_mapped_tags_on_template
    expect(@image_tag_mapping_category.children.collect(&:description)).to include(
      "suse-11-server-64",
      "ubuntu-12.04-server-32",
      # and many more...
    )

    template = ManageIQ::Providers::Amazon::CloudManager::Template.find_by(:name => "suse-11-server-64")
    expect(template.tags.count).to eq(1)
    expect(template.tags.first.category).to eq(@image_tag_mapping_category)
    expect(template.tags.first.classification.description).to eq("suse-11-server-64")
  end

  def assert_specific_service_offerings
    assert_specific_service_offering_with_no_portfolio
    assert_specific_service_offering_with_two_portfolios
    assert_specific_service_offering_with_rules
  end

  def assert_specific_service_offering_with_no_portfolio
    @service_offering_with_no_portfolio = ServiceOffering.find_by(:name => "EmsRefreshSpecProductWithNoPortfolio")
    expect(@service_offering_with_no_portfolio).to(
      have_attributes(
        "name"        => "EmsRefreshSpecProductWithNoPortfolio",
        "ems_ref"     => "prod-4v6rc4hwaiiha",
        "type"        => "ManageIQ::Providers::Amazon::CloudManager::ServiceOffering",
        "description" => nil,
        "ems_id"      => @ems.id,
        "extra"       => {
          "status"               => "CREATED",
          "product_arn"          => "arn:aws:catalog:us-east-1:200278856672:product/prod-4v6rc4hwaiiha",
          "created_time"         => format_time("2018-09-04T16:27:59.000+02:00"),
          "product_view_summary" => {
            "id"                  => "prodview-mojlvmp5xax74",
            "name"                => "EmsRefreshSpecProductWithNoPortfolio",
            "type"                => "CLOUD_FORMATION_TEMPLATE",
            "owner"               => "EmsRefreshSpecProductWithNoPortfolioOwner",
            "product_id"          => "prod-4v6rc4hwaiiha",
            "distributor"         => "",
            "support_url"         => nil,
            "support_email"       => nil,
            "has_default_path"    => false,
            "short_description"   => "EmsRefreshSpecProductWithNoPortfolio desc",
            "support_description" => nil
          }
        },
        "deleted_on"  => nil,
      )
    )

    expect(@service_offering_with_no_portfolio.service_parameters_sets.size).to eq 0
  end

  def assert_specific_service_offering_with_two_portfolios
    @service_offering_with_two_portfolios = ServiceOffering.find_by(:name => "EmsRefreshSpecProduct")
    expect(@service_offering_with_two_portfolios).to(
      have_attributes(
        "name"        => "EmsRefreshSpecProduct",
        "ems_ref"     => "prod-h7p6ruq5qgrga",
        "type"        => "ManageIQ::Providers::Amazon::CloudManager::ServiceOffering",
        "description" => nil,
        "ems_id"      => @ems.id,
        "extra"       => {
          "status"               => "CREATED",
          "product_arn"          => "arn:aws:catalog:us-east-1:200278856672:product/prod-h7p6ruq5qgrga",
          "created_time"         => format_time("2018-09-04T11:00:13.000+02:00"),
          "product_view_summary" => {
            "id"                  => "prodview-j3n5gqatjrkk2",
            "name"                => "EmsRefreshSpecProduct",
            "type"                => "CLOUD_FORMATION_TEMPLATE",
            "owner"               => "EmsRefreshSpecOwner",
            "product_id"          => "prod-h7p6ruq5qgrga",
            "distributor"         => "EmsRefreshSpecVendor",
            "support_url"         => "http://EmsRefreshSpec.com",
            "support_email"       => "EmsRefreshSpec@test.com",
            "has_default_path"    => false,
            "short_description"   => "EmsRefreshSpecProduct description",
            "support_description" => "EmsRefreshSpec desc"
          }
        },
        "deleted_on"  => nil,
      )
    )

    expect(@service_offering_with_two_portfolios.service_parameters_sets.pluck(:name, :ems_ref)).to(
      contain_exactly(
        ["EmsRefreshSpecProduct v2 EmsRefreshSpecPortfolio", "prod-h7p6ruq5qgrga__pa-nr3ua3nz3pgwq__lp-e76ssfhze5jyi"],
        ["EmsRefreshSpecProduct v3 EmsRefreshSpecPortfolio", "prod-h7p6ruq5qgrga__pa-ysaib55ylta6k__lp-e76ssfhze5jyi"],
        ["EmsRefreshSpecProduct v2 EmsRefreshSpecPortfolio2", "prod-h7p6ruq5qgrga__pa-nr3ua3nz3pgwq__lp-rb5sy6f5vyrdk"],
        ["EmsRefreshSpecProduct v3 EmsRefreshSpecPortfolio2", "prod-h7p6ruq5qgrga__pa-ysaib55ylta6k__lp-rb5sy6f5vyrdk"],
      )
    )
  end

  def assert_specific_service_offering_with_rules
    @service_offering_with_rules = ServiceOffering.find_by(:name => "EmsRefreshSpecProductWithRules")
    expect(@service_offering_with_rules).to(
      have_attributes(
        "name"        => "EmsRefreshSpecProductWithRules",
        "ems_ref"     => "prod-cei2spnzu24lq",
        "type"        => "ManageIQ::Providers::Amazon::CloudManager::ServiceOffering",
        "description" => nil,
        "ems_id"      => @ems.id,
        "extra"       => {
          "status"               => "CREATED",
          "product_arn"          => "arn:aws:catalog:us-east-1:200278856672:product/prod-cei2spnzu24lq",
          "created_time"         => format_time("2018-09-04T15:23:06.000+02:00"),
          "product_view_summary" => {
            "id"                  => "prodview-as7h736moeyrc",
            "name"                => "EmsRefreshSpecProductWithRules",
            "type"                => "CLOUD_FORMATION_TEMPLATE",
            "owner"               => "EmsRefreshSpecProductWithRulesowner",
            "product_id"          => "prod-cei2spnzu24lq",
            "distributor"         => "EmsRefreshSpecProductWithRulesVendor",
            "support_url"         => nil,
            "support_email"       => nil,
            "has_default_path"    => false,
            "short_description"   => "EmsRefreshSpecProductWithRules desc",
            "support_description" => nil
          }
        },
        "deleted_on"  => nil,
      )
    )

    expect(@service_offering_with_rules.service_parameters_sets.pluck(:name, :ems_ref)).to(
      contain_exactly(
        ["EmsRefreshSpecProductWithRules v1.1 EmsRefreshSpecPortfolio2", "prod-cei2spnzu24lq__pa-ybnrerfyrhm74__lp-jg4ob2tnq4pg2"]
      )
    )
  end

  def assert_specific_service_instances
    # There is no admin view, we need to provision the product using the VCR account:
    # Assign admin rights temporarily and run:
    # aws_service_catalog.client.provision_product(:product_id => "prod-h7p6ruq5qgrga", :provisioned_product_name => "EmsRefreshSpecServiceInstanceV3", :provisioning_artifact_id => "pa-ysaib55ylta6k", :path_id => "lp-e76ssfhze5jyi",:provisioning_parameters => [{:key => "InstanceType", :value => "t1.micro"}, {:key => "KeyName", :value => "EmsRefreshSpec-KeyPair"}])
    # aws_service_catalog.client.provision_product(:product_id => "prod-h7p6ruq5qgrga", :provisioned_product_name => "EmsRefreshSpecServiceInstance", :provisioning_artifact_id => "pa-nr3ua3nz3pgwq", :path_id => "lp-rb5sy6f5vyrdk", :provisioning_parameters => [{:key => "InstanceType", :value => "t1.micro"}, {:key => "KeyName", :value => "EmsRefreshSpec-KeyPair"}])
    # aws_service_catalog.client.provision_product(:product_id => "prod-cei2spnzu24lq", :provisioned_product_name => "EmsRefreshSpecServiceInstanceWithRules", :provisioning_artifact_id => "pa-ybnrerfyrhm74", :path_id => "lp-jg4ob2tnq4pg2", :provisioning_parameters => [{:key => "InstanceType", :value => "t1.micro"}, {:key => "KeyName", :value => "EmsRefreshSpec-KeyPair"}, {:key => "Environment", :value => "test"}])
    assert_specific_service_instance_with_rules
    assert_specific_service_instance_v3
    assert_specific_service_instance
  end

  def assert_specific_service_instance_with_rules
    @service_instance_with_rules = ServiceInstance.find_by(:name => "EmsRefreshSpecServiceInstanceWithRules")
    expect(@service_instance_with_rules).to(
      have_attributes(
        "name"                      => "EmsRefreshSpecServiceInstanceWithRules",
        "ems_ref"                   => "pp-5pyltbgyzheqm",
        "type"                      => "ManageIQ::Providers::Amazon::CloudManager::ServiceInstance",
        "ems_id"                    => @ems.id,
        "service_offering_id"       => @service_offering_with_rules.try(:id),
        "service_parameters_set_id" => service_parameter_set(@service_instance_with_rules).try(:id),
        "extra"                     => {
          "arn"                 => "arn:aws:servicecatalog:us-east-1:200278856672:stack/EmsRefreshSpecServiceInstanceWithRules/pp-5pyltbgyzheqm",
          "type"                => "CFN_STACK",
          "status"              => "AVAILABLE",
          "created_time"        => format_time("2018-09-04T15:38:38.933+02:00"),
          "last_record_id"      => "rec-li62bnn6bnza4",
          "status_message"      => nil,
          "idempotency_token"   => "39489a07-f013-4e49-a061-11360db7664c",
          "last_record_detail"  => {
            "status"                   => "SUCCEEDED",
            "path_id"                  => "lp-jg4ob2tnq4pg2",
            "record_id"                => "rec-li62bnn6bnza4",
            "product_id"               => "prod-cei2spnzu24lq",
            "record_tags"              => [
              {
                "key"   => "aws:servicecatalog:productArn",
                "value" => "arn:aws:catalog:us-east-1:200278856672:product/prod-cei2spnzu24lq"
              }, {
                "key"   => "aws:servicecatalog:provisioningPrincipalArn",
                "value" => "arn:aws:iam::200278856672:user/VCR"
              }, {
                "key"   => "aws:servicecatalog:portfolioArn",
                "value" => "arn:aws:catalog:us-east-1:200278856672:portfolio/port-dg3wqzbxza75m"
              }
            ],
            "record_type"              => "PROVISION_PRODUCT",
            "created_time"             => format_time("2018-09-04T15:38:38.937+02:00"),
            "updated_time"             => format_time("2018-09-04T15:41:31.778+02:00"),
            "record_errors"            => [],
            "provisioned_product_id"   => "pp-5pyltbgyzheqm",
            "provisioned_product_name" => "EmsRefreshSpecServiceInstanceWithRules",
            "provisioned_product_type" => "CFN_STACK",
            "provisioning_artifact_id" => "pa-ybnrerfyrhm74"
          },
          "last_record_outputs" => [
            {
              "output_key"   => "CloudformationStackARN",
              "description"  => "The ARN of the launched Cloudformation Stack",
              "output_value" => "arn:aws:cloudformation:us-east-1:200278856672:stack/SC-200278856672-pp-5pyltbgyzheqm/d51dd9b0-b047-11e8-a5af-500c28709a35"
            }, {
              "output_key"   => "URL",
              "description"  => "URL of the website",
              "output_value" => "http://SC-200278-ElasticL-FDREQLBTVJ1Z-177825134.us-east-1.elb.amazonaws.com"
            }
          ]
        },
        "deleted_on"                => nil,
      )
    )
  end

  def assert_specific_service_instance_v3
    @service_instance_v3 = ServiceInstance.find_by(:name => "EmsRefreshSpecServiceInstanceV3")
    expect(@service_instance_v3).to(
      have_attributes(
        "name"                      => "EmsRefreshSpecServiceInstanceV3",
        "ems_ref"                   => "pp-u2tepcnttldko",
        "type"                      => "ManageIQ::Providers::Amazon::CloudManager::ServiceInstance",
        "ems_id"                    => @ems.id,
        "service_offering_id"       => @service_offering_with_two_portfolios.try(:id),
        "service_parameters_set_id" => service_parameter_set(@service_instance_v3).try(:id),
        "extra"                     => {
          "arn"                 =>
                                   "arn:aws:servicecatalog:us-east-1:200278856672:stack/EmsRefreshSpecServiceInstanceV3/pp-u2tepcnttldko",
          "type"                => "CFN_STACK",
          "status"              => "AVAILABLE",
          "created_time"        => format_time("2018-09-06T10:18:51.782+02:00"),
          "last_record_id"      => "rec-coaoipufhru7e",
          "status_message"      => nil,
          "idempotency_token"   => "c4de373d-fc6b-45ac-a7d0-760b6be25756",
          "last_record_detail"  => {
            "status"                   => "SUCCEEDED",
            "path_id"                  => "lp-e76ssfhze5jyi",
            "record_id"                => "rec-coaoipufhru7e",
            "product_id"               => "prod-h7p6ruq5qgrga",
            "record_tags"              => [
              {"key"   => "aws:servicecatalog:productArn",
               "value" =>
                          "arn:aws:catalog:us-east-1:200278856672:product/prod-h7p6ruq5qgrga"},
              {"key"   => "aws:servicecatalog:provisioningPrincipalArn",
               "value" => "arn:aws:iam::200278856672:user/VCR"},
              {"key"   => "aws:servicecatalog:portfolioArn",
               "value" =>
                          "arn:aws:catalog:us-east-1:200278856672:portfolio/port-4qwgmfklkgosk"}
            ],
            "record_type"              => "PROVISION_PRODUCT",
            "created_time"             => format_time("2018-09-06T10:18:51.789+02:00"),
            "updated_time"             => format_time("2018-09-06T10:22:08.309+02:00"),
            "record_errors"            => [],
            "provisioned_product_id"   => "pp-u2tepcnttldko",
            "provisioned_product_name" => "EmsRefreshSpecServiceInstanceV3",
            "provisioned_product_type" => "CFN_STACK",
            "provisioning_artifact_id" => "pa-ysaib55ylta6k"
          },
          "last_record_outputs" => [
            {"output_key"   => "CloudformationStackARN",
             "description"  => "The ARN of the launched Cloudformation Stack",
             "output_value" =>
                               "arn:aws:cloudformation:us-east-1:200278856672:stack/SC-200278856672-pp-u2tepcnttldko/7db5dfd0-b1ad-11e8-b3ce-500c524294d2"},
            {"output_key"   => "URL",
             "description"  => "URL of the website",
             "output_value" =>
                               "http://SC-200278-ElasticL-OHBTSYAE8C89-342178717.us-east-1.elb.amazonaws.com"}
          ]
        },
        "deleted_on"                => nil,
      )
    )
  end

  def assert_specific_service_instance
    @service_instance = ServiceInstance.find_by(:name => "EmsRefreshSpecServiceInstance")
    expect(@service_instance).to(
      have_attributes(
        "name"                      => "EmsRefreshSpecServiceInstance",
        "ems_ref"                   => "pp-gato4drzgerpy",
        "type"                      => "ManageIQ::Providers::Amazon::CloudManager::ServiceInstance",
        "ems_id"                    => @ems.id,
        "service_offering_id"       => @service_offering_with_two_portfolios.try(:id),
        "service_parameters_set_id" => service_parameter_set(@service_instance).try(:id),
        "extra"                     => {
          "arn"                 =>
                                   "arn:aws:servicecatalog:us-east-1:200278856672:stack/EmsRefreshSpecServiceInstance/pp-gato4drzgerpy",
          "type"                => "CFN_STACK",
          "status"              => "AVAILABLE",
          "created_time"        => format_time("2018-09-06T10:19:14.188+02:00"),
          "last_record_id"      => "rec-txbigs6rk7vlc",
          "status_message"      => nil,
          "idempotency_token"   => "bd5ea4d0-de72-45be-a28b-2bfe9ae8e509",
          "last_record_detail"  => {
            "status"                   => "SUCCEEDED",
            "path_id"                  => "lp-rb5sy6f5vyrdk",
            "record_id"                => "rec-txbigs6rk7vlc",
            "product_id"               => "prod-h7p6ruq5qgrga",
            "record_tags"              => [
              {"key"   => "aws:servicecatalog:productArn",
               "value" =>
                          "arn:aws:catalog:us-east-1:200278856672:product/prod-h7p6ruq5qgrga"},
              {"key"   => "aws:servicecatalog:provisioningPrincipalArn",
               "value" => "arn:aws:iam::200278856672:user/VCR"},
              {"key"   => "aws:servicecatalog:portfolioArn",
               "value" =>
                          "arn:aws:catalog:us-east-1:200278856672:portfolio/port-dg3wqzbxza75m"}
            ],
            "record_type"              => "PROVISION_PRODUCT",
            "created_time"             => format_time("2018-09-06T10:19:14.197+02:00"),
            "updated_time"             => format_time("2018-09-06T10:22:54.450+02:00"),
            "record_errors"            => [],
            "provisioned_product_id"   => "pp-gato4drzgerpy",
            "provisioned_product_name" => "EmsRefreshSpecServiceInstance",
            "provisioned_product_type" => "CFN_STACK",
            "provisioning_artifact_id" => "pa-nr3ua3nz3pgwq"
          },
          "last_record_outputs" => [
            {"output_key"   => "CloudformationStackARN",
             "description"  => "The ARN of the launched Cloudformation Stack",
             "output_value" =>
                               "arn:aws:cloudformation:us-east-1:200278856672:stack/SC-200278856672-pp-gato4drzgerpy/8addcb50-b1ad-11e8-a5af-500c28709a35"},
            {"output_key"   => "URL",
             "description"  => "URL of the website",
             "output_value" =>
                               "http://SC-200278-ElasticL-G69XH7HDIQ0J-169282342.us-east-1.elb.amazonaws.com"}
          ]
        },
        "deleted_on"                => nil,
      )
    )
  end

  def service_parameter_set(record)
    rec_detail = record.extra["last_record_detail"]

    ServiceParametersSet.find_by(
      :ems_ref => "#{rec_detail["product_id"]}__#{rec_detail["provisioning_artifact_id"]}__#{rec_detail["path_id"]}"
    )
  end

  def format_time(time)
    Time.parse(time).localtime.iso8601(3)
  end
end
