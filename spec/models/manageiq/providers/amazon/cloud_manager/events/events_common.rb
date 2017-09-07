module EventsCommon
  def response(path)
    response = double
    allow(response).to receive(:body).and_return(
      File.read(File.join(File.dirname(__FILE__), "/event_catcher/#{path}"))
    )

    allow(response).to receive(:message_id).and_return("mocked_message_id")

    response
  end

  def parse_event(path)
    ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Stream.new(double).send(:parse_event, response(path))
  end

  def create_ems_event(path)
    event = ManageIQ::Providers::Amazon::CloudManager::EventCatcher::Stream.new(double).send(:parse_event, response(path))
    event_hash = ManageIQ::Providers::Amazon::CloudManager::EventParser.event_to_hash(event, @ems.id)
    EmsEvent.add(@ems.id, event_hash)
  end
end
