class ManageIQ::Providers::Amazon::Provider < ::Provider
  has_one  :object_storage_manager,
           :foreign_key => "provider_id",
           :class_name  => "ManageIQ::Providers::Amazon::StorageManager::S3",
           :autosave    => true
  has_many :cloud_ems,
           :foreign_key => "provider_id",
           :class_name  => "ManageIQ::Providers::Amazon::CloudManager",
           :dependent   => :nullify,
           :autosave    => true
  has_many :network_managers,
           :foreign_key => "provider_id",
           :class_name  => "ManageIQ::Providers::Amazon::NetworkManager",
           :autosave    => true
  has_many :block_storage_managers,
           :foreign_key => "provider_id",
           :class_name  => "ManageIQ::Providers::Amazon::StorageManager::Ebs",
           :autosave    => true

  validates :name, :presence => true, :uniqueness => true
end
