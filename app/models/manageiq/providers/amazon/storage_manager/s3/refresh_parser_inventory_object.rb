class ManageIQ::Providers::Amazon::StorageManager::S3::RefreshParserInventoryObject < ::ManagerRefresh::RefreshParserInventoryObject
  include ManageIQ::Providers::Amazon::RefreshHelperMethods

  def populate_inventory_collections
    log_header = "MIQ(#{self.class.name}.#{__method__}) Collecting data for EMS name: [#{inventory.ems.name}] id: [#{inventory.ems.id}]"

    $aws_log.info("#{log_header}...}")
    object_store
    $aws_log.info("#{log_header}...Complete")

    inventory_collections
  end

  private

  def object_store
    process_inventory_collection(
      inventory.cloud_object_store_containers,
      :cloud_object_store_containers
    ) { |c| parse_container(c) }
  end

  def parse_container(bucket)
    uid = bucket['name']
    {
      :ems_ref => uid,
      :key     => bucket['name']
    }
  end
end
