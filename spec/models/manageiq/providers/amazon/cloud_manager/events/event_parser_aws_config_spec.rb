describe ManageIQ::Providers::Amazon::CloudManager::EventParser do
  include EventsCommon

  context ".event_to_hash" do
    it "parses vm_ems_ref into event" do
      message               = JSON.parse(File.read(File.join(File.dirname(__FILE__), "/event_catcher/sqs_message.json")))
      event                 = JSON.parse(message['Message'])
      event["eventType"]    = 'AWS_EC2_Instance_UPDATE'
      event["event_source"] = :config
      expect(described_class.event_to_hash(event, nil)).to include(:vm_ems_ref => 'i-06199fba')
    end
  end

  context "AWS Config Event" do
    it "parses vm_ems_ref into event" do
      event = parse_event("sqs_message.json")

      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref => 'i-06199fba',
          :timestamp  => "2016-01-29T08:09:24.720Z"
        )
      )
    end
  end

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
end
