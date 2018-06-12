describe ManageIQ::Providers::Amazon::CloudManager::EventTargetParser do
  before :each do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems                 = FactoryGirl.create(:ems_amazon, :zone => zone)

    allow_any_instance_of(EmsEvent).to receive(:handle_event)
    allow(EmsEvent).to receive(:create_completed_event)
  end

  context "AWS Config Event" do
    it "parses vm_ems_ref into event" do
      ems_event = create_ems_event("sqs_message.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-06199fba'}])
    end

    it "parses AWS_CloudFormation_Stack_CREATE event" do
      ems_event = create_ems_event("config/AWS_CloudFormation_Stack_CREATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:orchestration_stacks, {:ems_ref => "arn:aws:cloudformation:us-east-1:200278856672:stack/ladas-test31/0fb199a0-93c4-11e7-998e-500c217b4a62"}]
          ]
        )
      )
    end

    it "parses AWS_CloudFormation_Stack_DELETE.json event" do
      ems_event = create_ems_event("config/AWS_CloudFormation_Stack_DELETE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:orchestration_stacks, {:ems_ref => "arn:aws:cloudformation:us-east-1:200278856672:stack/ladas-test-22/ec875e20-93a9-11e7-b549-500c28b23699"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_EIP_CREATE event" do
      ems_event = create_ems_event("config/AWS_EC2_EIP_CREATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:floating_ips, {:ems_ref => "eipalloc-3d8a720f"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_EIP_DELETE event" do
      ems_event = create_ems_event("config/AWS_EC2_EIP_DELETE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:floating_ips, {:ems_ref => "eipalloc-45584474"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_EIP_UPDATE event" do
      ems_event = create_ems_event("config/AWS_EC2_EIP_UPDATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:floating_ips, {:ems_ref => "eipalloc-3d8a720f"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_Instance_CREATE event" do
      ems_event = create_ems_event("config/AWS_EC2_Instance_CREATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:vms, {:ems_ref => "i-0b72e0b70e7fae3c9"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_Instance_DELETE event" do
      ems_event = create_ems_event("config/AWS_EC2_Instance_DELETE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:vms, {:ems_ref => "i-04863b664ebf1facf"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_Instance_running event" do
      ems_event = create_ems_event("config/AWS_EC2_Instance_running.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:vms, {:ems_ref => "i-fb694e66"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_Instance_stopped event" do
      ems_event = create_ems_event("config/AWS_EC2_Instance_stopped.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:vms, {:ems_ref => "i-0f7f3f02eaf99ea4b"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_Instance_stopping event" do
      ems_event = create_ems_event("config/AWS_EC2_Instance_stopping.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:vms, {:ems_ref => "i-02975d4eb8e53bafd"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_Instance_UPDATE event" do
      ems_event = create_ems_event("config/AWS_EC2_Instance_UPDATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:vms, {:ems_ref => "i-0b72e0b70e7fae3c9"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_InternetGateway_CREATE event" do
      ems_event = create_ems_event("config/AWS_EC2_InternetGateway_CREATE.json")

      parsed_targets = described_class.new(ems_event).parse

      # TODO(lsmola) we do not refresh and model Gateway
      expect(parsed_targets.size).to eq(0)
    end

    it "parses AWS_EC2_InternetGateway_DELETE event" do
      ems_event = create_ems_event("config/AWS_EC2_InternetGateway_DELETE.json")

      parsed_targets = described_class.new(ems_event).parse

      # TODO(lsmola) we do not refresh and model Gateway
      expect(parsed_targets.size).to eq(0)
    end

    it "parses AWS_EC2_NetworkAcl_CREATE event" do
      ems_event = create_ems_event("config/AWS_EC2_NetworkAcl_CREATE.json")

      parsed_targets = described_class.new(ems_event).parse

      # TODO(lsmola) we do not refresh and model NetworkAcl
      expect(parsed_targets.size).to eq(0)
    end

    it "parses AWS_EC2_NetworkAcl_UPDATE_event" do
      ems_event = create_ems_event("config/AWS_EC2_NetworkAcl_UPDATE.json")

      parsed_targets = described_class.new(ems_event).parse

      # TODO(lsmola) we do not refresh and model NetworkAcl
      expect(parsed_targets.size).to eq(0)
    end

    it "parses AWS_EC2_NetworkInterface_CREATE event" do
      ems_event = create_ems_event("config/AWS_EC2_NetworkInterface_CREATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:network_ports, {:ems_ref => "eni-b9cc7f19"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_NetworkInterface_DELETE event" do
      ems_event = create_ems_event("config/AWS_EC2_NetworkInterface_DELETE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:network_ports, {:ems_ref => "eni-fd37e25d"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_NetworkInterface_UPDATE event" do
      ems_event = create_ems_event("config/AWS_EC2_NetworkInterface_UPDATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:network_ports, {:ems_ref => "eni-b9cc7f19"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_RouteTable_CREATE event" do
      ems_event = create_ems_event("config/AWS_EC2_RouteTable_CREATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(0)
    end

    it "parses AWS_EC2_RouteTable_DELETE event" do
      ems_event = create_ems_event("config/AWS_EC2_RouteTable_DELETE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(0)
    end

    it "parses AWS_EC2_RouteTable_UPDATE event" do
      ems_event = create_ems_event("config/AWS_EC2_RouteTable_UPDATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(0)
    end

    it "parses AWS_EC2_SecurityGroup_CREATE event" do
      ems_event = create_ems_event("config/AWS_EC2_SecurityGroup_CREATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:security_groups, {:ems_ref => "sg-aaa85e3c"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_SecurityGroup_DELETE event" do
      ems_event = create_ems_event("config/AWS_EC2_SecurityGroup_DELETE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:security_groups, {:ems_ref => "sg-b30cfb25"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_SecurityGroup_UPDATE event" do
      ems_event = create_ems_event("config/AWS_EC2_SecurityGroup_UPDATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:security_groups, {:ems_ref => "sg-80f755ef"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_Subnet_CREATE event" do
      ems_event = create_ems_event("config/AWS_EC2_Subnet_CREATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_subnets, {:ems_ref => "subnet-5f5a9670"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_Subnet_DELETE event" do
      ems_event = create_ems_event("config/AWS_EC2_Subnet_DELETE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_subnets, {:ems_ref => "subnet-84055dde"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_Subnet_UPDATE event" do
      ems_event = create_ems_event("config/AWS_EC2_Subnet_UPDATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_subnets, {:ems_ref => "subnet-f849ff96"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_Volume_CREATE event" do
      ems_event = create_ems_event("config/AWS_EC2_Volume_CREATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_volumes, {:ems_ref => "vol-0ac7a66512bf0d20c"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_Volume_DELETE event" do
      ems_event = create_ems_event("config/AWS_EC2_Volume_DELETE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_volumes, {:ems_ref => "vol-0f0e3e1c4a2f2d285"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_Volume_UPDATE event" do
      ems_event = create_ems_event("config/AWS_EC2_Volume_UPDATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_volumes, {:ems_ref => "vol-01ff7e549707b8e54"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_VPC_CREATE event" do
      ems_event = create_ems_event("config/AWS_EC2_VPC_CREATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref => "vpc-2e7df256"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_VPC_DELETE event" do
      ems_event = create_ems_event("config/AWS_EC2_VPC_DELETE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref => "vpc-4d73fc35"}]
          ]
        )
      )
    end

    it "parses AWS_EC2_VPC_UPDATE event" do
      ems_event = create_ems_event("config/AWS_EC2_VPC_UPDATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref => "vpc-ff49ff91"}]
          ]
        )
      )
    end

    it 'parses EBS_Snapshot_Notification event' do
      ems_event = create_ems_event("config/EBS_Snapshot_Notification.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets))
        .to match_array([[:cloud_volume_snapshots, { :ems_ref => 'snap-0089df02c4373d7a0' }]])
    end
  end

  context "AWS CloudWatch with CloudTrail API" do
    it "parses AWS_API_CALL_AllocateAddress" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_AllocateAddress.json")
      parsed_targets = described_class.new(ems_event).parse

      # TODO(lsmola) we get just \"publicIp\":\"23.23.209.146\" for domain standard, we have to test also VPC and see
      # what targets we can parse there
      expect(parsed_targets.size).to eq(0)
      expect(target_references(parsed_targets)).to(
        match_array(
          []
        )
      )
    end

    it "parses AWS_API_CALL_ApplySecurityGroupsToLoadBalancer" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_ApplySecurityGroupsToLoadBalancer.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:load_balancers, {:ems_ref => "lb-test3"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_AssignPrivateIpAddresses" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_AssignPrivateIpAddresses.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:network_ports, {:ems_ref => "eni-6933e6c9"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_AssociateAddress" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_AssociateAddress.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:floating_ips, {:ems_ref => "eipalloc-3d8a720f"}],
            [:vms, {:ems_ref => "i-0b72e0b70e7fae3c9"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_AssociateDhcpOptions" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_AssociateDhcpOptions.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref=>"vpc-d87ff0a0"}],
          ]
        )
      )
    end

    it "parses AWS_API_CALL_AssociateRouteTable" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_AssociateRouteTable.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_subnets, {:ems_ref=>"subnet-43992b7c"}],
          ]
        )
      )
    end

    it "parses AWS_API_CALL_AttachInternetGateway" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_AttachInternetGateway.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref=>"vpc-2e7df256"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_AttachNetworkInterface" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_AttachNetworkInterface.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:network_ports, {:ems_ref => "eni-83fc5323"}],
            [:vms, {:ems_ref => "i-099e794cfa830e9be"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_AttachVolume" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_AttachVolume.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(4)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_volumes, {:ems_ref => "vol-0b817789420231c3c"}],
            [:vms, {:ems_ref => "i-02975d4eb8e53bafd"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_AuthorizeSecurityGroupIngress" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_AuthorizeSecurityGroupIngress.json")
      parsed_targets = described_class.new(ems_event).parse

      # TODO)(lsmola) there seems to be only \"groupName\":\"ladas-test31-InstanceSecurityGroup-WB54OMZ9Y46R\"} present
      # we should figure out what to do.
      expect(parsed_targets.size).to eq(0)
      expect(target_references(parsed_targets)).to(
        match_array(
          []
        )
      )
    end

    it "parses AWS_API_CALL_ConfigureHealthCheck" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_ConfigureHealthCheck.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:load_balancers, {:ems_ref => "ladas-tes-ElasticL-1TF5KASVJA6TN"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_CopySnapshot" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CopySnapshot.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_volume_snapshots, {:ems_ref=>"snap-0b1bfdb21caec2dcd"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_CreateImage" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateImage.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:miq_templates, {:ems_ref => "ami-bbc9dac0"}],
            [:vms, {:ems_ref => "i-099e794cfa830e9be"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_CreateInternetGateway" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateInternetGateway.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(0)
      expect(target_references(parsed_targets)).to(
        match_array(
          []
        )
      )
    end

    it "parses AWS_API_CALL_CreateKeyPair" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateKeyPair.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:key_pairs, {:name => "test_vcr_key_pair"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_CreateLoadBalancer" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateLoadBalancer.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:load_balancers, {:ems_ref => "ladas-tes-ElasticL-1TF5KASVJA6TN"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_CreateLoadBalancerListeners" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateLoadBalancerListeners.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:load_balancers, {:ems_ref => "lb-test3"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_CreateNetworkInterface" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateNetworkInterface.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(6)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref => "vpc-ff49ff91"}],
            [:cloud_subnets, {:ems_ref => "subnet-16c70477"}],
            [:network_ports, {:ems_ref => "eni-f2397458"}],
            [:security_groups, {:ems_ref => "sg-0d2cd677"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_CreateRoute" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateRoute.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(0)
    end

    it "parses AWS_API_CALL_CreateRouteTable" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateRouteTable.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref=>"vpc-2e7df256"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_CreateSecurityGroup" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateSecurityGroup.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:security_groups, {:ems_ref => "sg-aaa85e3c"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_CreateSnapshot" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateSnapshot.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(3)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_volume_snapshots, {:ems_ref => "snap-07650aa40098a0da2"}],
            [:cloud_volumes, {:ems_ref => "vol-0382343901be51311"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_CreateStack" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateStack.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:orchestration_stacks, {:ems_ref => "ladas-test31"}],
            [:orchestration_stacks, {:ems_ref => "arn:aws:cloudformation:us-east-1:200278856672:stack/ladas-test31/0fb199a0-93c4-11e7-998e-500c217b4a62"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_CreateSubnet" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateSubnet.json")
      parsed_targets = described_class.new(ems_event).parse

      # TODO(lsmola) there is {\"subnetId\":\"subnet-84055dde\", why is it not being parsed?
      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref => "vpc-ff49ff91"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_CreateTags" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateTags.json")
      parsed_targets = described_class.new(ems_event).parse

      # TODO(lsmola) we are not parsing tags events now, we should
      expect(parsed_targets.size).to eq(0)
      expect(target_references(parsed_targets)).to(
        match_array(
          []
        )
      )
    end

    it "parses AWS_API_CALL_CreateVolume" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateVolume.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(3)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_volume_snapshots, {:ems_ref => "snap-07650aa40098a0da2"}],
            [:cloud_volumes, {:ems_ref => "vol-0f0e3e1c4a2f2d285"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_CreateVpc" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_CreateVpc.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref=>"vpc-d87ff0a0"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_DeleteInternetGateway" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeleteInternetGateway.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(0)
    end

    it "parses AWS_API_CALL_DeleteKeyPair" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeleteKeyPair.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:key_pairs, {:name => "test_vcr_key_pair"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_DeleteLoadBalancer" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeleteLoadBalancer.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:load_balancers, {:ems_ref => "ladas-tes-ElasticL-19VL2K06WQ7KI"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_DeleteNetworkInterface" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeleteNetworkInterface.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:network_ports, {:ems_ref=>"eni-3f67fd15"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_DeleteRoute" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeleteRoute.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(0)
    end

    it "parses AWS_API_CALL_DeleteRouteTable" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeleteRouteTable.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(0)
    end

    it "parses AWS_API_CALL_DeleteSecurityGroup" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeleteSecurityGroup.json")
      parsed_targets = described_class.new(ems_event).parse

      # TODO(lsmola) Only GroupName present \"groupName\":\"ladas-test-22-InstanceSecurityGroup-1SG39VFG1U29M\"
      expect(parsed_targets.size).to eq(0)
      expect(target_references(parsed_targets)).to(
        match_array(
          []
        )
      )
    end

    it "parses AWS_API_CALL_DeleteSnapshot" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeleteSnapshot.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_volume_snapshots, {:ems_ref => "snap-07650aa40098a0da2"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_DeleteStack" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeleteStack.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:orchestration_stacks, {:ems_ref => "arn:aws:cloudformation:us-east-1:200278856672:stack/ladas-test-22/ec875e20-93a9-11e7-b549-500c28b23699"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_DeleteSubnet" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeleteSubnet.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_subnets, {:ems_ref => "subnet-84055dde"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_DeleteTags" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeleteTags.json")
      parsed_targets = described_class.new(ems_event).parse

      # TODO(lsmola) track tags
      expect(parsed_targets.size).to eq(0)
      expect(target_references(parsed_targets)).to(
        match_array(
          []
        )
      )
    end

    it "parses AWS_API_CALL_DeleteVolume" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeleteVolume.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_volumes, {:ems_ref => "vol-01a43f2173a0ee4ac"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_DeleteVpc" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeleteVpc.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref=>"vpc-a06de3c5"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_DeregisterImage" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeregisterImage.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:miq_templates, {:ems_ref=>"ami-a944c4d3"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_DeregisterInstancesFromLoadBalancer" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DeregisterInstancesFromLoadBalancer.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:load_balancers, {:ems_ref => "ladas-tes-ElasticL-19VL2K06WQ7KI"}],
            [:vms, {:ems_ref => "i-04863b664ebf1facf"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_DetachInternetGateway.json" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DetachInternetGateway.json")
      parsed_targets = described_class.new(ems_event).parse

      # TODO(lsmola) event mentions only attachmentId, which we do not track
      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref=>"vpc-a06de3c5"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_DetachNetworkInterface.json" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DetachNetworkInterface.json")
      parsed_targets = described_class.new(ems_event).parse

      # TODO(lsmola) event mentions only attachmentId, which we do not track
      expect(parsed_targets.size).to eq(0)
      expect(target_references(parsed_targets)).to(
        match_array(
          []
        )
      )
    end

    it "parses AWS_API_CALL_DetachVolume" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DetachVolume.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(4)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_volumes, {:ems_ref => "vol-01a43f2173a0ee4ac"}],
            [:vms, {:ems_ref => "i-02975d4eb8e53bafd"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_DisassociateAddress.json" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DisassociateAddress.json")
      parsed_targets = described_class.new(ems_event).parse

      # TODO(lsmola) mentions only associationId we do not track, should we?
      expect(parsed_targets.size).to eq(0)
      expect(target_references(parsed_targets)).to(
        match_array(
          []
        )
      )
    end

    it "parses AWS_API_CALL_DisassociateRouteTable.json" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_DisassociateRouteTable.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(0)
      expect(target_references(parsed_targets)).to(
        match_array(
          []
        )
      )
    end

    it "parses AWS_API_CALL_EnableVpcClassicLinkDnsSupport.json" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_EnableVpcClassicLinkDnsSupport.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref=>"vpc-d87ff0a0"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_EnableVpcClassicLink.json" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_EnableVpcClassicLink.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref=>"vpc-d87ff0a0"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_ImportKeyPair.json" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_ImportKeyPair.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:key_pairs, {:name => "ladas_test_2"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_ModifyLoadBalancerAttributes" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_ModifyLoadBalancerAttributes.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:load_balancers, {:ems_ref => "ladas-tes-ElasticL-1TF5KASVJA6TN"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_ModifyNetworkInterfaceAttribute" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_ModifyNetworkInterfaceAttribute.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(4)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:network_ports, {:ems_ref => "eni-fd35bd0e"}],
            [:security_groups, {:ems_ref => "sg-734efc0f"}],
            [:security_groups, {:ems_ref => "sg-0d2cd677"}],
            [:security_groups, {:ems_ref => "sg-da58eaa6"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_ModifyVpcAttribute" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_ModifyVpcAttribute.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_networks, {:ems_ref=>"vpc-d87ff0a0"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_RebootInstances" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_RebootInstances.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:vms, {:ems_ref => "i-0a83d1c42220da9a1"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_RegisterImage" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_RegisterImage.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:miq_templates, {:ems_ref => "ami-45c9df3e"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_RegisterInstancesWithLoadBalancer" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_RegisterInstancesWithLoadBalancer.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(3)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:load_balancers, {:ems_ref => "ladas-tes-ElasticL-1TF5KASVJA6TN"}],
            [:vms, {:ems_ref => "i-00945be3d7c07ec6c"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_ReleaseAddress" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_ReleaseAddress.json")
      parsed_targets = described_class.new(ems_event).parse

      # TODO(lsmola) again only {\"publicIp\":\"23.21.100.183\"} mentioned, not sure what domain
      expect(parsed_targets.size).to eq(0)
      expect(target_references(parsed_targets)).to(
        match_array(
          []
        )
      )
    end

    it "parses AWS_API_CALL_ReplaceRouteTableAssociation" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_ReplaceRouteTableAssociation.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(0)
      expect(target_references(parsed_targets)).to(
        match_array(
          []
        )
      )
    end

    it "parses AWS_API_CALL_RevokeSecurityGroupEgress" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_RevokeSecurityGroupEgress.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:security_groups, {:ems_ref=>"sg-cf2dd7be"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_RevokeSecurityGroupIngress" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_RevokeSecurityGroupIngress.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:security_groups, {:ems_ref=>"sg-f0d92a94"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_RunInstances" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_RunInstances.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(14)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_subnets, {:ems_ref => "subnet-f849ff96"}],
            [:security_groups, {:ems_ref => "sg-80f755ef"}],
            [:miq_templates, {:ems_ref => "ami-2051294a"}],
            [:key_pairs, {:name => "ladas"}],
            [:vms, {:ems_ref => "i-0b72e0b70e7fae3c9"}],
            [:cloud_networks, {:ems_ref => "vpc-ff49ff91"}],
            [:network_ports, {:ems_ref => "eni-b9cc7f19"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_SetLoadBalancerPoliciesOfListener" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_SetLoadBalancerPoliciesOfListener.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:load_balancers, {:ems_ref => "ladas-tes-ElasticL-1TF5KASVJA6TN"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_SignalResource" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_SignalResource.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:orchestration_stacks, {:ems_ref => "ladas-test31"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_StartInstances event" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_StartInstances.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:vms, {:ems_ref => 'i-0aeefa44d61669849'}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_StopInstances" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_StopInstances.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:vms, {:ems_ref => 'i-0aeefa44d61669849'}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_TerminateInstances" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_TerminateInstances.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:vms, {:ems_ref => "i-04863b664ebf1facf"}]
          ]
        )
      )
    end

    it "parses AWS_API_CALL_UnassignPrivateIpAddresses" do
      ems_event      = create_ems_event("cloud_watch/AWS_API_CALL_UnassignPrivateIpAddresses.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:network_ports, {:ems_ref => "eni-6933e6c9"}]
          ]
        )
      )
    end
  end

  context "AWS CloudWatch EC2" do
    it "parses EC2_Instance_State_change_Notification_pending event" do
      ems_event      = create_ems_event("cloud_watch/EC2_Instance_State_change_Notification_pending.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-0aeefa44d61669849'}])
    end

    it "parses EC2_Instance_State_change_Notification_running event" do
      ems_event      = create_ems_event("cloud_watch/EC2_Instance_State_change_Notification_running.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-0aeefa44d61669849'}])
    end

    it "parses EC2_Instance_State_change_Notification_shutting-down event" do
      ems_event      = create_ems_event("cloud_watch/EC2_Instance_State_change_Notification_shutting-down.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-04863b664ebf1facf'}])
    end

    it "parses EC2_Instance_State_change_Notification_stopped event" do
      ems_event      = create_ems_event("cloud_watch/EC2_Instance_State_change_Notification_stopped.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-0aeefa44d61669849'}])
    end

    it "parses EC2_Instance_State_change_Notification_stopping event" do
      ems_event      = create_ems_event("cloud_watch/EC2_Instance_State_change_Notification_stopping.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-02975d4eb8e53bafd'}])
    end

    it "parses EC2_Instance_State_change_Notification_terminated event" do
      ems_event      = create_ems_event("cloud_watch/EC2_Instance_State_change_Notification_terminated.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-04863b664ebf1facf'}])
    end
  end

  context "AWS CloudWatch Alarm" do
    it "parses AWS_ALARM_awselb-EmSRefreshSpecVPCELB-Unhealthy-Hosts alarm event" do
      ems_event = create_ems_event("cloud_watch/AWS_ALARM_awselb-EmSRefreshSpecVPCELB-Unhealthy-Hosts.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(0)
    end
  end

  def target_references(parsed_targets)
    parsed_targets.map { |x| [x.association, x.manager_ref] }.uniq
  end

  def response(path)
    response = double
    allow(response).to receive(:body).and_return(
      File.read(File.join(File.dirname(__FILE__), "/event_catcher/#{path}"))
    )

    allow(response).to receive(:message_id).and_return("mocked_message_id")

    response
  end

  def create_ems_event(path)
    event = ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Stream.new(double).send(:parse_event, response(path))
    event_hash = ManageIQ::Providers::Amazon::CloudManager::EventParser.event_to_hash(event, @ems.id)
    EmsEvent.add(@ems.id, event_hash)
  end
end
