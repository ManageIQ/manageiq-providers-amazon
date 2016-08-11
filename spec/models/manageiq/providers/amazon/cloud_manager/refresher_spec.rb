describe ManageIQ::Providers::Amazon::CloudManager::Refresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_amazon, :zone => zone)
    @ems.update_authentication(:default => {:userid => "0123456789ABCDEFGHIJ", :password => "ABCDEFGHIJKLMNO1234567890abcdefghijklmno"})
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ec2)
  end

  it "will perform a full refresh" do
    2.times do # Run twice to verify that a second run with existing data does not change anything
      @ems.reload

      VCR.use_cassette(described_class.name.underscore) do
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems.network_manager)
      end
      @ems.reload

      assert_table_counts
      assert_ems
      assert_specific_flavor
      assert_specific_az
      assert_specific_floating_ip
      assert_specific_floating_ip_for_cloud_network
      assert_specific_key_pair
      assert_specific_cloud_network
      assert_specific_security_group
      assert_specific_security_group_on_cloud_network
      assert_specific_template
      assert_specific_shared_template
      assert_specific_vm_powered_on
      assert_specific_vm_powered_off
      assert_specific_vm_on_cloud_network
      assert_specific_vm_in_other_region
      assert_specific_load_balancers
      assert_specific_load_balancer_listeners
      assert_specific_load_balancer_health_checks
      assert_specific_orchestration_template
      assert_specific_orchestration_stack
      assert_relationship_tree
    end
  end

  def expected_table_counts
    {
      :auth_private_key              => 12,
      :ext_management_system         => 2,
      :flavor                        => 56,
      :availability_zone             => 5,
      :vm_or_template                => 47,
      :vm                            => 27,
      :miq_template                  => 20,
      :disk                          => 14,
      :guest_device                  => 0,
      :hardware                      => 47,
      :network                       => 15,
      :operating_system              => 0,
      :snapshot                      => 0,
      :system_service                => 0,
      :relationship                  => 30,
      :miq_queue                     => 50,
      :orchestration_template        => 3,
      :orchestration_stack           => 4,
      :orchestration_stack_parameter => 10,
      :orchestration_stack_output    => 1,
      :orchestration_stack_resource  => 45,
      :security_group                => 37,
      :firewall_rule                 => 99,
      :network_port                  => 33,
      :cloud_network                 => 5,
      :floating_ip                   => 5,
      :network_router                => 0,
      :cloud_subnet                  => 10,
      :custom_attribute              => 0
    }
  end

  def assert_table_counts
    actual = {
      :auth_private_key              => AuthPrivateKey.count,
      :ext_management_system         => ExtManagementSystem.count,
      :flavor                        => Flavor.count,
      :availability_zone             => AvailabilityZone.count,
      :vm_or_template                => VmOrTemplate.count,
      :vm                            => Vm.count,
      :miq_template                  => MiqTemplate.count,
      :disk                          => Disk.count,
      :guest_device                  => GuestDevice.count,
      :hardware                      => Hardware.count,
      :network                       => Network.count,
      :operating_system              => OperatingSystem.count,
      :snapshot                      => Snapshot.count,
      :system_service                => SystemService.count,
      :relationship                  => Relationship.count,
      :miq_queue                     => MiqQueue.count,
      :orchestration_template        => OrchestrationTemplate.count,
      :orchestration_stack           => OrchestrationStack.count,
      :orchestration_stack_parameter => OrchestrationStackParameter.count,
      :orchestration_stack_output    => OrchestrationStackOutput.count,
      :orchestration_stack_resource  => OrchestrationStackResource.count,
      :security_group                => SecurityGroup.count,
      :firewall_rule                 => FirewallRule.count,
      :network_port                  => NetworkPort.count,
      :cloud_network                 => CloudNetwork.count,
      :floating_ip                   => FloatingIp.count,
      :network_router                => NetworkRouter.count,
      :cloud_subnet                  => CloudSubnet.count,
      :custom_attribute              => CustomAttribute.count
    }

    expect(actual).to eq expected_table_counts
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version => nil, # TODO: Should be 3.0
      :uid_ems     => nil
    )

    expect(@ems.flavors.size).to eql(expected_table_counts[:flavor])
    expect(@ems.availability_zones.size).to eql(expected_table_counts[:availability_zone])
    expect(@ems.vms_and_templates.size).to eql(expected_table_counts[:vm_or_template])
    expect(@ems.security_groups.size).to eql(expected_table_counts[:security_group])
    expect(@ems.network_ports.size).to eql(expected_table_counts[:network_port])
    expect(@ems.cloud_networks.size).to eql(expected_table_counts[:cloud_network])
    expect(@ems.floating_ips.size).to eql(expected_table_counts[:floating_ip])
    expect(@ems.network_routers.size).to eql(expected_table_counts[:network_router])
    expect(@ems.cloud_subnets.size).to eql(expected_table_counts[:cloud_subnet])
    expect(@ems.miq_templates.size).to eq(expected_table_counts[:miq_template])

    expect(@ems.orchestration_stacks.size).to eql(expected_table_counts[:orchestration_stack])
    expect(@ems.direct_orchestration_stacks.size).to eql(3)
  end

  def assert_specific_flavor
    @flavor = ManageIQ::Providers::Amazon::CloudManager::Flavor.where(:name => "t1.micro").first
    expect(@flavor).to have_attributes(
      :name                     => "t1.micro",
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
      :ems_ref            => "54.221.202.53",
      :cloud_network_only => false
    )
  end

  def assert_specific_floating_ip_for_cloud_network
    ip = ManageIQ::Providers::Amazon::NetworkManager::FloatingIp.where(:address => "54.208.119.197").first
    expect(ip).to have_attributes(
      :address            => "54.208.119.197",
      :ems_ref            => "54.208.119.197",
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

  def assert_specific_cloud_network
    @cn = CloudNetwork.where(:name => "EmsRefreshSpec-VPC").first
    expect(@cn).to have_attributes(
      :name    => "EmsRefreshSpec-VPC",
      :ems_ref => "vpc-ff49ff91",
      :cidr    => "10.0.0.0/16",
      :status  => "inactive",
      :enabled => true
    )

    expect(@cn.cloud_subnets.size).to eq(2)
    @subnet = @cn.cloud_subnets.where(:name => "EmsRefreshSpec-Subnet1").first
    expect(@subnet).to have_attributes(
      :name    => "EmsRefreshSpec-Subnet1",
      :ems_ref => "subnet-f849ff96",
      :cidr    => "10.0.0.0/24"
    )
    expect(@subnet.availability_zone)
      .to eq(ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.where(:name => "us-east-1e").first)

    subnet2 = @cn.cloud_subnets.where(:name => "EmsRefreshSpec-Subnet2").first
    expect(subnet2).to have_attributes(
      :name    => "EmsRefreshSpec-Subnet2",
      :ems_ref => "subnet-16c70477",
      :cidr    => "10.0.1.0/24"
    )
    expect(subnet2.availability_zone)
      .to eq(ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.where(:name => "us-east-1d").first)
  end

  def assert_specific_security_group
    @sg = ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup.where(:name => "EmsRefreshSpec-SecurityGroup1").first
    expect(@sg).to have_attributes(
      :name        => "EmsRefreshSpec-SecurityGroup1",
      :description => "EmsRefreshSpec-SecurityGroup1",
      :ems_ref     => "sg-038e8a69"
    )

    expected_firewall_rules = [
      {:host_protocol => "ICMP", :direction => "inbound", :port => -1, :end_port => -1,    :source_ip_range => "0.0.0.0/0",  :source_security_group_id => nil},
      {:host_protocol => "ICMP", :direction => "inbound", :port => -1, :end_port => -1,    :source_ip_range => nil,          :source_security_group_id => @sg.id},
      {:host_protocol => "ICMP", :direction => "inbound", :port => 0,  :end_port => -1,    :source_ip_range => "1.2.3.4/30", :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 0,  :end_port => 65535, :source_ip_range => "0.0.0.0/0",  :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 1,  :end_port => 2,     :source_ip_range => "1.2.3.4/30", :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 3,  :end_port => 4,     :source_ip_range => nil,          :source_security_group_id => @sg.id},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 80, :end_port => 80,    :source_ip_range => "0.0.0.0/0",  :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 80, :end_port => 80,    :source_ip_range => "1.2.3.4/30", :source_security_group_id => nil},
      {:host_protocol => "TCP",  :direction => "inbound", :port => 80, :end_port => 80,    :source_ip_range => nil,          :source_security_group_id => @sg.id},
      {:host_protocol => "UDP",  :direction => "inbound", :port => 0,  :end_port => 65535, :source_ip_range => "0.0.0.0/0",  :source_security_group_id => nil},
      {:host_protocol => "UDP",  :direction => "inbound", :port => 1,  :end_port => 2,     :source_ip_range => "1.2.3.4/30", :source_security_group_id => nil},
      {:host_protocol => "UDP",  :direction => "inbound", :port => 3,  :end_port => 4,     :source_ip_range => nil,          :source_security_group_id => @sg.id}
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
      :location              => "200278856672/EmsRefreshSpec-Image",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => nil,
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
    expect(@template.operating_system).to       be_nil # TODO: This should probably not be nil
    expect(@template.custom_attributes.size).to eq(0)
    expect(@template.snapshots.size).to eq(0)

    expect(@template.hardware).to have_attributes(
      :guest_os            => "linux",
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

  def assert_specific_shared_template
    # TODO: Share an EmsRefreshSpec specific template
    t = ManageIQ::Providers::Amazon::CloudManager::Template.where(:ems_ref => "ami-5769193e").first
    expect(t).not_to be_nil
  end

  def assert_specific_vm_powered_on
    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(
      :name            => "EmsRefreshSpec-PoweredOn-Basic3",
      :raw_power_state => "running").first
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "i-680071e9",
      :ems_ref_obj           => nil,
      :uid_ems               => "i-680071e9",
      :vendor                => "amazon",
      :power_state           => "on",
      :location              => "ec2-54-221-202-53.compute-1.amazonaws.com",
      :tools_status          => nil,
      :boot_time             => "2016-03-29T07:49:56.000",
      :standby_action        => nil,
      :connection_state      => nil,
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
    expect(v.availability_zone).to eq(@az)
    expect(v.floating_ip).to eq(@ip)
    expect(v.flavor).to eq(@flavor)
    expect(v.key_pairs).to eq([@kp])
    expect(v.cloud_network).to     be_nil
    expect(v.cloud_subnet).to      be_nil
    sg_2 = ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup
           .where(:name => "EmsRefreshSpec-SecurityGroup2").first
    expect(v.security_groups)
      .to match_array [sg_2, @sg]

    expect(v.operating_system).to       be_nil # TODO: This should probably not be nil
    expect(v.custom_attributes.size).to eq(0)
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :guest_os            => "linux",
      :guest_os_full_name  => nil,
      :bios                => nil,
      :annotation          => nil,
      :cpu_sockets         => 1,
      :memory_mb           => 627,
      :disk_capacity       => 0, # TODO: Change to a flavor that has disks
      :bitness             => 64,
      :virtualization_type => "paravirtual"
    )

    expect(v.hardware.disks.size).to eq(0) # TODO: Change to a flavor that has disks
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
      :ipaddress   => "10.65.160.22",
      :hostname    => "ip-10-65-160-22.ec2.internal"
    )

    v.with_relationship_type("genealogy") do
      expect(v.parent).to eq(@template)
    end
  end

  def assert_specific_vm_powered_off
    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(
      :name            => "EmsRefreshSpec-PoweredOff",
      :raw_power_state => "stopped").first
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "i-6eeb97ef",
      :ems_ref_obj           => nil,
      :uid_ems               => "i-6eeb97ef",
      :vendor                => "amazon",
      :power_state           => "off",
      :location              => "unknown",
      :tools_status          => nil,
      :boot_time             => "2016-01-08T15:09:18.000",
      :standby_action        => nil,
      :connection_state      => nil,
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
      .to eq(ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.find_by_name("us-east-1e"))
    expect(v.floating_ip).to be_nil
    expect(v.key_pairs).to eq([@kp])
    expect(v.cloud_network).to be_nil
    expect(v.cloud_subnet).to be_nil
    expect(v.security_groups).to eq([@sg])
    expect(v.operating_system).to be_nil # TODO: This should probably not be nil
    expect(v.custom_attributes.size).to eq(0)
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :config_version       => nil,
      :virtual_hw_version   => nil,
      :guest_os             => "linux",
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

    expect(v.hardware.disks.size).to eq(0) # TODO: Change to a flavor that has disks
    expect(v.hardware.guest_devices.size).to eq(0)
    expect(v.hardware.nics.size).to eq(0)
    expect(v.hardware.networks.size).to eq(0)

    v.with_relationship_type("genealogy") do
      expect(v.parent).to eq(@template)
    end
  end

  def assert_specific_vm_on_cloud_network
    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(:name => "EmsRefreshSpec-PoweredOn-VPC").first
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "i-8b5739f2",
      :ems_ref_obj           => nil,
      :uid_ems               => "i-8b5739f2",
      :vendor                => "amazon",
      :power_state           => "on",
      :location              => "unknown",
      :tools_status          => nil,
      :boot_time             => "2016-08-10 15:34:32.000000000 +0000",
      :standby_action        => nil,
      :connection_state      => nil,
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

    expect(v.cloud_networks.first).to eq(@cn)
    expect(v.cloud_subnets.first).to eq(@subnet)
    expect(v.security_groups).to eq([@sg_on_cn])
  end

  def assert_specific_load_balancers
    @elb_non_vpc = ManageIQ::Providers::Amazon::CloudManager::LoadBalancer.where(
      :name => "EmsRefreshSpec-LoadBalancer").first
    expect(@elb_non_vpc).to have_attributes(
                              "ems_ref"         => "EmsRefreshSpec-LoadBalancer",
                              "name"            => "EmsRefreshSpec-LoadBalancer",
                              "description"     => nil,
                              "cloud_tenant_id" => nil,
                              "type"            => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer")

    expect(@elb_non_vpc.ext_management_system).to eq(@ems.network_manager)

    @elb = ManageIQ::Providers::Amazon::CloudManager::LoadBalancer.where(
      :name => "EmSRefreshSpecVPCELB").first
    expect(@elb).to have_attributes(
                      "ems_ref"         => "EmSRefreshSpecVPCELB",
                      "name"            => "EmSRefreshSpecVPCELB",
                      "description"     => nil,
                      "cloud_tenant_id" => nil,
                      "type"            => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer")

    expect(@elb.ext_management_system).to eq(@ems.network_manager)
    # TODO(lsmola)
    # expect(@elb.availability_zones).to eq(@az)
    # expect(@elb.cloud_subnets).to eq(..)
    # expect(@elb.network_ports).to eq(..)

    @elb2 = ManageIQ::Providers::Amazon::CloudManager::LoadBalancer.where(
      :name => "EmSRefreshSpecVPCELB2").first
    expect(@elb2).to have_attributes(
                       "ems_ref"         => "EmSRefreshSpecVPCELB2",
                       "name"            => "EmSRefreshSpecVPCELB2",
                       "description"     => nil,
                       "cloud_tenant_id" => nil,
                       "type"            => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancer")

    expect(@elb2.ext_management_system).to eq(@ems.network_manager)

    expect(@elb.vms.count).to eq 2
    expect(@elb.load_balancer_pool_members.count).to eq 2
    expect(@elb.load_balancer_pool_members.first.ext_management_system).to eq @ems.network_manager
    expect(@elb.vms.first.ext_management_system).to eq @ems
    expect(@elb.vms.collect(&:name)).to match_array ["EmsRefreshSpec-PoweredOn-VPC", "VMstate-8"]

    expect(@elb.vms).to match_array @elb2.vms
    expect(@elb.load_balancer_pool_members).to match_array @elb2.load_balancer_pool_members

    expect(@elb_non_vpc.load_balancer_pool_members.count).to eq 1
    expect(@elb_non_vpc.vms.first.name).to eq "EmsRefreshSpec-PoweredOn-Basic3"
  end

  def assert_specific_load_balancer_listeners
    expect(@elb_non_vpc.load_balancer_listeners.count).to eq 1
    expect(@elb.load_balancer_listeners.count).to eq 2
    expect(@elb2.load_balancer_listeners.count).to eq 1

    @listener_non_vpc = @elb_non_vpc.load_balancer_listeners
                          .where(:ems_ref => "EmsRefreshSpec-LoadBalancer__HTTP__80__HTTP__80__").first
    expect(@listener_non_vpc).to have_attributes(
                                   "ems_ref"                => "EmsRefreshSpec-LoadBalancer__HTTP__80__HTTP__80__",
                                   "name"                   => nil,
                                   "description"            => nil,
                                   "load_balancer_protocol" => "HTTP",
                                   "load_balancer_port"     => 80,
                                   "instance_protocol"      => "HTTP",
                                   "instance_port"          => 80,
                                   "cloud_tenant_id"        => nil,
                                   "type"                   => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener"
                                 )
    expect(@listener_non_vpc.ext_management_system).to eq(@ems.network_manager)

    listener_1 = @elb.load_balancer_listeners
                   .where(:ems_ref => "EmSRefreshSpecVPCELB__TCP__22__TCP__22__").first
    expect(listener_1).to have_attributes(
                            "ems_ref"                => "EmSRefreshSpecVPCELB__TCP__22__TCP__22__",
                            "name"                   => nil,
                            "description"            => nil,
                            "load_balancer_protocol" => "TCP",
                            "load_balancer_port"     => 22,
                            "instance_protocol"      => "TCP",
                            "instance_port"          => 22,
                            "cloud_tenant_id"        => nil,
                            "type"                   => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener"
                          )
    expect(listener_1.ext_management_system).to eq(@ems.network_manager)

    @listener_2 = @elb.load_balancer_listeners
                    .where(:ems_ref => "EmSRefreshSpecVPCELB__HTTP__80__HTTP__80__").first
    expect(@listener_2).to have_attributes(
                             "ems_ref"                => "EmSRefreshSpecVPCELB__HTTP__80__HTTP__80__",
                             "name"                   => nil,
                             "description"            => nil,
                             "load_balancer_protocol" => "HTTP",
                             "load_balancer_port"     => 80,
                             "instance_protocol"      => "HTTP",
                             "instance_port"          => 80,
                             "cloud_tenant_id"        => nil,
                             "type"                   => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener"
                           )
    expect(@listener_2.ext_management_system).to eq(@ems.network_manager)

    @listener_3 = @elb2.load_balancer_listeners.first
    expect(@listener_3).to have_attributes(
                             "ems_ref"                => "EmSRefreshSpecVPCELB2__TCP__2222__TCP__22__",
                             "name"                   => nil,
                             "description"            => nil,
                             "load_balancer_protocol" => "TCP",
                             "load_balancer_port"     => 2222,
                             "instance_protocol"      => "TCP",
                             "instance_port"          => 22,
                             "cloud_tenant_id"        => nil,
                             "type"                   => "ManageIQ::Providers::Amazon::NetworkManager::LoadBalancerListener"
                           )
    expect(@listener_3.ext_management_system).to eq(@ems.network_manager)
  end

  def assert_specific_load_balancer_health_checks
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

    expect(health_check_1.load_balancer_listener).to eq @listener_2

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

    expect(health_check_2.load_balancer_listener).to eq @listener_3

    expect(health_check_1.load_balancer_pool_members.count).to eq 2
    expect(health_check_1.load_balancer_pool_members).to match_array health_check_2.load_balancer_pool_members
    expect(health_check_1.vms).to match_array health_check_2.vms
  end

  def assert_specific_orchestration_template
    @orch_template = OrchestrationTemplateCfn.where(:md5 => "e929859521d64ac28ee29f8526d33e8f").first
    expect(@orch_template.description).to start_with("AWS CloudFormation Sample Template WordPress_Simple:")
    expect(@orch_template.content).to start_with("{\n  \"AWSTemplateFormatVersion\" : \"2010-09-09\",")
    expect(@orch_template).to have_attributes(:draft => false, :orderable => false)
  end

  def assert_specific_orchestration_stack
    stack = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack.where(
      :name => "EmsRefreshSpecStack").first
    expect(stack.status_reason)
      .to eq("The following resource(s) failed to create: [IPAddress]. ")

    @orch_stack = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack.where(
      :name => "EmsRefreshSpecStack-WebServerInstance-KA9UQBMIC3NR").first
    expect(@orch_stack).to have_attributes(
      :status  => "CREATE_COMPLETE",
      :ems_ref => "arn:aws:cloudformation:us-east-1:200278856672:stack/EmsRefreshSpecStack-WebServerInstance-KA9UQBMIC3NR/8be435c0-5f20-11e6-9323-50d5cafe7636",
    )
    expect(@orch_stack.description).to start_with("AWS CloudFormation Sample Template WordPress_Simple:")

    assert_specific_orchestration_stack_parameters
    assert_specific_orchestration_stack_resources
    assert_specific_orchestration_stack_outputs
    assert_specific_orchestration_stack_associations
  end

  def assert_specific_orchestration_stack_parameters
    parameters = @orch_stack.parameters.order("ems_ref")
    expect(parameters.size).to eq(2)

    # assert one of the parameter models
    expect(parameters[1]).to have_attributes(
      :name  => "InstanceType",
      :value => "t1.micro"
    )
  end

  def assert_specific_orchestration_stack_resources
    resources = @orch_stack.resources.order("ems_ref")
    expect(resources.size).to eq(4)

    # assert one of the resource models
    expect(resources[3]).to have_attributes(
      :name                   => "WebServer",
      :logical_resource       => "WebServer",
      :physical_resource      => "i-df132341",
      :resource_category      => "AWS::EC2::Instance",
      :resource_status        => "CREATE_COMPLETE",
      :resource_status_reason => nil,
    )
  end

  def assert_specific_orchestration_stack_outputs
    outputs = @orch_stack.outputs
    expect(outputs.size).to eq(1)
    expect(outputs[0]).to have_attributes(
      :key         => "WebsiteURL",
      :value       => "http://ec2-54-158-72-174.compute-1.amazonaws.com/wordpress",
      :description => "WordPress Website"
    )
  end

  def assert_specific_orchestration_stack_associations
    # orchestration stack belongs to a provider
    expect(@orch_stack.ext_management_system).to eq(@ems)

    # orchestration stack belongs to an orchestration template
    expect(@orch_stack.orchestration_template).to eq(@orch_template)

    # orchestration stack can be nested
    parent_stack = OrchestrationStack.where(:name => "EmsRefreshSpecStack").first
    expect(@orch_stack.parent).to eq(parent_stack)

    # orchestration stack can have vms
    vm = Vm.where(:name => "i-df132341").first
    expect(vm.orchestration_stack).to eq(@orch_stack)

    # orchestration stack can have security groups
    sg = SecurityGroup.where(
      :name => "EmsRefreshSpecStack-WebServerInstance-KA9UQBMIC3NR-WebServerSecurityGroup-1P9L0V2V3NYRX").first
    expect(sg.orchestration_stack).to eq(@orch_stack)

    # orchestration stack can have cloud networks
    vpc = CloudNetwork.where(:name => "vpc-d7c3a8b0").first
    expect(vpc.orchestration_stack).to eq(parent_stack)
  end

  def assert_specific_vm_in_other_region
    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(:name => "EmsRefreshSpec-PoweredOn-OtherRegion").first
    expect(v).to be_nil
  end

  def assert_relationship_tree
    expect(@ems.descendants_arranged).to match_relationship_tree({})
  end
end
