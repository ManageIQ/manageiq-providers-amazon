class ManageIQ::Providers::Amazon::Inventory::Targets::StorageManager::Ebs < ManageIQ::Providers::Amazon::Inventory::Targets
  def initialize_inventory_collections
    add_inventory_collections(%i(cloud_volumes cloud_volume_snapshots))

    add_inventory_collections(%i(availability_zones),
                              :parent   => ems.parent_manager,
                              :strategy => :local_db_cache_all)
  end

  def cloud_volumes
    HashCollection.new(aws_ec2.client.describe_volumes[:volumes])
  end

  def cloud_volume_snapshots
    HashCollection.new(aws_ec2.client.describe_snapshots(:owner_ids => [:self])[:snapshots])
  end
end
