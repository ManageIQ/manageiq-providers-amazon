class ManageIQ::Providers::Amazon::Inventory::Collector::StorageManager::Ebs < ManageIQ::Providers::Amazon::Inventory::Collector
  def cloud_volumes
    hash_collection.new(aws_ec2.client.describe_volumes.flat_map(&:volumes))
  end

  def cloud_volume_snapshots
    hash_collection.new(aws_ec2.client.describe_snapshots(:owner_ids => [:self]).flat_map(&:snapshots))
  end
end
