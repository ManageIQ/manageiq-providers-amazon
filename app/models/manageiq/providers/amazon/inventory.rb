class ManageIQ::Providers::Amazon::Inventory
  attr_reader :ems, :options, :target, :collector, :parsers_classes

  delegate :inventory_collections, :to => :target

  def initialize(ems, raw_target, target_class: nil, collector_class: nil, parsers_classes: nil)
    @ems     = ems
    @options = Settings.ems_refresh[ems.class.ems_type]

    @collector = collector_class.new(@ems, @options, raw_target)
    @target    = target_class.new(@collector)

    @parsers_classes = parsers_classes
  end

  def parse
    parsers_classes.each { |parser_class| parser_class.new(@target).populate_inventory_collections }

    inventory_collections.values
  end
end
