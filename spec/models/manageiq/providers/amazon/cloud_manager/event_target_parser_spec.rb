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

    it "CloudFormation_StackCreate" do
      ems_event = create_ems_event("config/AWS_CloudFormation_Stack_CREATE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to(
        match_array([{:ems_ref=>"arn:aws:cloudformation:us-east-1:200278856672:stack/ladas-test31/0fb199a0-93c4-11e7-998e-500c217b4a62"}])
      )
    end

    it "CloudFormation_StackDelete" do
      ems_event = create_ems_event("config/AWS_CloudFormation_Stack_DELETE.json")

      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to(
        match_array([{:ems_ref=>"arn:aws:cloudformation:us-east-1:200278856672:stack/ladas-test-22/ec875e20-93a9-11e7-b549-500c28b23699"}])
      )
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
            [:vms, {:ems_ref => "i-0b72e0b70e7fae3c9"}]]
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

      # TODO(lsmola) recorded VCR has error The maximum number of internet gateways has been reached, so maybe we can
      # parse targets here
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

      # TODO(lsmola) VCR containes error The maximum number of VPCs has been reached, rerecord, we should see
      # cloud_network target inside
      expect(parsed_targets.size).to eq(0)
      expect(target_references(parsed_targets)).to(
        match_array(
          []
        )
      )
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
