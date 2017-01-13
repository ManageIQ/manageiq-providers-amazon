describe ManageIQ::Providers::Amazon::CloudManager::EventParser do
  context ".event_to_hash" do
    it "parses vm_ems_ref into event" do
      message = JSON.parse(File.read(File.join(File.dirname(__FILE__), "/event_catcher/sqs_message.json")))
      event   = JSON.parse(message['Message'])
      event["eventType"] = 'AWS_EC2_Instance_UPDATE'
      expect(described_class.event_to_hash(event, nil)).to include(:vm_ems_ref => 'i-06199fba')
    end
  end
end
