module ManageIQ::Providers
  class Amazon::NetworkManager::Refresher < ManageIQ::Providers::BaseManager::Refresher
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
          ManageIQ::Providers::Amazon::NetworkManager::RefreshParserInventoryObject.new(inventory).populate_inventory_collections
        else
          ManageIQ::Providers::Amazon::NetworkManager::RefreshParser.ems_inv_to_hashes(ems, refresher_options)
        end
      end
      _log.debug "#{log_header} Parsing inventory...Complete"

      hashes
    end

    def post_process_refresh_classes
      []
    end
  end
end
