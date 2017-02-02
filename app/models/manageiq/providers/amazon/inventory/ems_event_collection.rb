class ManageIQ::Providers::Amazon::Inventory::EmsEventCollection
  attr_accessor :targets

  def initialize(targets)
    @targets = targets
  end

  def all_related_ems_events(ems)
    # We want all EmsEvents around the time of collected EmsEvents, and to the future since AWS send all related events
    # at once
    EmsEvent.where(:ems_id => ems.id).where(:timestamp => datetime_min..DateTime::Infinity.new).order("timestamp DESC")
  end

  def datetime_min
    targets.collect(&:timestamp).min - 3.minutes
  end

  def name
    "Collection of EmsEvent targets with name: #{targets.collect(&:name)}"
  end

  def id
    "Collection of EmsEvent targets with id: #{targets.collect(&:id)}"
  end
end
