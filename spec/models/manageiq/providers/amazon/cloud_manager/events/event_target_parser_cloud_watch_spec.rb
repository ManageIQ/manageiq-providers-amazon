describe ManageIQ::Providers::Amazon::CloudManager::EventTargetParser do
  before :each do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems                 = FactoryGirl.create(:ems_amazon, :zone => zone)

    allow_any_instance_of(EmsEvent).to receive(:handle_event)
    allow(EmsEvent).to receive(:create_completed_event)
  end

  context "AWS CloudWatch with CloudTrail API" do
    it "parses AWS_API_CALL_StartInstances event" do
      ems_event = create_ems_event("cloud_watch/AWS_API_CALL_StartInstances.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-0aeefa44d61669849'}])
    end

    it "parses AWS_API_CALL_StopInstances" do
      ems_event = create_ems_event("cloud_watch/AWS_API_CALL_StopInstances.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(2)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-0aeefa44d61669849'}])
    end
  end

  context "AWS CloudWatch EC2" do
    it "parses EC2_Instance_State_change_Notification_pending event" do
      ems_event = create_ems_event("cloud_watch/EC2_Instance_State_change_Notification_pending.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-0aeefa44d61669849'}])
    end

    it "parses EC2_Instance_State_change_Notification_running event" do
      ems_event = create_ems_event("cloud_watch/EC2_Instance_State_change_Notification_running.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-0aeefa44d61669849'}])
    end

    it "parses EC2_Instance_State_change_Notification_stopped event" do
      ems_event = create_ems_event("cloud_watch/EC2_Instance_State_change_Notification_stopped.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(1)
      expect(parsed_targets.collect(&:manager_ref).uniq).to match_array([{:ems_ref => 'i-0aeefa44d61669849'}])
    end
  end

  context "AWS CloudWatch Alarm" do
    it "parses AWS_ALARM_awselb-EmSRefreshSpecVPCELB-Unhealthy-Hosts alarm event" do
      ems_event = create_ems_event("cloud_watch/AWS_ALARM_awselb-EmSRefreshSpecVPCELB-Unhealthy-Hosts.json")
      parsed_targets = described_class.new(ems_event).parse

      expect(parsed_targets.size).to eq(0)
    end
  end
end
