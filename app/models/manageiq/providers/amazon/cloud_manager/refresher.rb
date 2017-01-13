class ManageIQ::Providers::Amazon::CloudManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
  include ::EmsRefresh::Refreshers::EmsRefresherMixin

  def collect_inventory_for_targets(ems, targets)
    targets_with_data = targets.collect do |target|
      target_name = target.try(:name) || target.try(:event_type)

      _log.info "Filtering inventory for #{target.class} [#{target_name}] id: [#{target.id}]..."

      inventory = if refresher_options.try(:[], :inventory_object_refresh)
                    ManageIQ::Providers::Amazon::Inventory::Factory.inventory(ems, target)
                  else
                    nil
                  end

      _log.info "Filtering inventory...Complete"
      [target, inventory]
    end

    targets_with_data
  end

  def parse_targeted_inventory(ems, _target, inventory)
    log_header = format_ems_for_logging(ems)
    _log.debug "#{log_header} Parsing inventory..."
    hashes, = Benchmark.realtime_block(:parse_inventory) do
      if refresher_options.try(:[], :inventory_object_refresh)
        ManageIQ::Providers::Amazon::CloudManager::RefreshParserInventoryObject.new(inventory).populate_inventory_collections
      else
        ManageIQ::Providers::Amazon::CloudManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
      end
    end
    _log.debug "#{log_header} Parsing inventory...Complete"

    hashes
  end

  # TODO(lsmola) NetworkManager, remove this once we have a full representation of the NetworkManager.
  # NetworkManager should refresh base on its own conditions
  def save_inventory(ems, target, inventory_collections)
    EmsRefresh.save_ems_inventory(ems, inventory_collections)
    EmsRefresh.queue_refresh(ems.network_manager) if target.kind_of?(ManageIQ::Providers::BaseManager)
  end

  def post_process_refresh_classes
    [::Vm]
  end
end
