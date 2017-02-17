class ManageIQ::Providers::Amazon::Inventory::Parser::StorageManager::S3 < ManageIQ::Providers::Amazon::Inventory::Parser
  def ems
    collector.manager.respond_to?(:s3_storage_manager) ? collector.manager.s3_storage_manager : collector.manager
  end

  def parse
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{collector.manager.name}] id: [#{collector.manager.id}]"

    $aws_log.info("#{log_header}...}")
    object_store
    $aws_log.info("#{log_header}...Complete")
  end

  private

  def object_store
    process_inventory_collection(
      collector.cloud_object_store_containers,
      :cloud_object_store_containers
    ) { |c| parse_container(c) }
  end

  def parse_container(bucket)
    uid = bucket['name']
    {
      :ext_management_system => ems,
      :ems_ref               => uid,
      :key                   => bucket['name']
    }
  end
end
