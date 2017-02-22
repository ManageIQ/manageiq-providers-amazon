describe ManageIQ::Providers::Amazon::CloudManager::EventParser do
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

      expect(described_class.event_to_hash(event, nil)).to include(:vm_ems_ref => 'i-06199fba')
    end
  end

  context "AWS CloudWatch with CloudTrail API" do
    it "parses StartInstances event" do
      event = parse_event("cloud_watch/StartInstances.json")

      expect(described_class.event_to_hash(event, nil)).to include(:vm_ems_ref => 'i-0aeefa44d61669849')
    end

    it "parses StopInstances" do
      event = parse_event("cloud_watch/StopInstances.json")

      expect(described_class.event_to_hash(event, nil)).to include(:vm_ems_ref => 'i-0aeefa44d61669849')
    end
  end

  context "AWS CloudWatch EC2" do
    it "parses EC2_Instance_State_change_Notification_pending event" do
      event = parse_event("cloud_watch/EC2_Instance_State_change_Notification_pending.json")

      expect(described_class.event_to_hash(event, nil)).to include(:vm_ems_ref => 'i-0aeefa44d61669849')
    end

    it "parses EC2_Instance_State_change_Notification_running event" do
      event = parse_event("cloud_watch/EC2_Instance_State_change_Notification_running.json")

      expect(described_class.event_to_hash(event, nil)).to include(:vm_ems_ref => 'i-0aeefa44d61669849')
    end

    it "parses EC2_Instance_State_change_Notification_stopped event" do
      event = parse_event("cloud_watch/EC2_Instance_State_change_Notification_stopped.json")

      expect(described_class.event_to_hash(event, nil)).to include(:vm_ems_ref => 'i-0aeefa44d61669849')
    end
  end

  context "AWS CloudWatch Alarm" do
    it "parses AWS_ALARM_awselb-EmSRefreshSpecVPCELB-Unhealthy-Hosts alarm event" do
      event = parse_event("cloud_watch/AWS_ALARM_awselb-EmSRefreshSpecVPCELB-Unhealthy-Hosts.json")

      expect(described_class.event_to_hash(event, nil)).to(
        include(:vm_ems_ref => nil, :message => "awselb-EmSRefreshSpecVPCELB-Unhealthy-Hosts")
      )
    end
  end

  def response(path)
    response = double
    allow(response).to receive(:body).and_return(
      File.read(File.join(File.dirname(__FILE__), "/event_catcher/#{path}")))

    allow(response).to receive(:message_id).and_return("mocked_message_id")

    response
  end

  def parse_event(path)
    ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Stream.new(double).send(:parse_event, response(path))
  end
end
