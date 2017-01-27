class ManageIQ::Providers::Amazon::Inventory::TargetCollection
  attr_accessor :targets

  def initialize(targets)
    @targets = targets
  end

  def name
    "Collection of targets with name: #{targets.collect(&:name)}"
  end

  def id
    "Collection of targets with id: #{targets.collect(&:id)}"
  end
end
