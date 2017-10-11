describe ManageIQ::Providers::Amazon::CloudManager::EventTargetParser do
  include EventsCommon

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
  end
end
