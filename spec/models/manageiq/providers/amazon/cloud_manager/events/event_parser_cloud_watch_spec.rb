describe ManageIQ::Providers::Amazon::CloudManager::EventParser do
  include EventsCommon

  context "AWS CloudWatch with CloudTrail API" do
    it "parses StartInstances event" do
      event = parse_event("cloud_watch/AWS_API_CALL_StartInstances.json")

      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref => 'i-0aeefa44d61669849',
          :timestamp  => "2017-01-31T15:55:09Z"
        )
      )
    end

    it "parses StopInstances" do
      event = parse_event("cloud_watch/AWS_API_CALL_StopInstances.json")

      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref => 'i-0aeefa44d61669849',
          :timestamp  => "2017-01-31T15:51:23Z"
        )
      )
    end
  end

  context "AWS CloudWatch EC2" do
    it "parses EC2_Instance_State_change_Notification_pending event" do
      event = parse_event("cloud_watch/EC2_Instance_State_change_Notification_pending.json")

      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref => 'i-0aeefa44d61669849',
          :timestamp  => "2017-01-31T15:55:09Z"
        )
      )
    end

    it "parses EC2_Instance_State_change_Notification_running event" do
      event = parse_event("cloud_watch/EC2_Instance_State_change_Notification_running.json")

      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref => 'i-0aeefa44d61669849',
          :timestamp  => "2017-01-31T15:55:38Z"
        )
      )
    end

    it "parses EC2_Instance_State_change_Notification_stopped event" do
      event = parse_event("cloud_watch/EC2_Instance_State_change_Notification_stopped.json")

      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref => 'i-0aeefa44d61669849',
          :timestamp  => "2017-01-31T15:52:32Z"
        )
      )
    end
  end

  context "AWS CloudWatch Alarm" do
    it "parses AWS_ALARM_awselb-EmSRefreshSpecVPCELB-Unhealthy-Hosts alarm event" do
      event = parse_event("cloud_watch/AWS_ALARM_awselb-EmSRefreshSpecVPCELB-Unhealthy-Hosts.json")

      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref => nil,
          :message    => "awselb-EmSRefreshSpecVPCELB-Unhealthy-Hosts",
          :timestamp  => "2017-02-22T09:18:26.916+0000"
        )
      )
    end
  end
end
