module ManageIQ::Providers::Amazon::ParserHelperMethods
  extend ActiveSupport::Concern

  #
  # Helper methods
  #
  def filter_unused_disabled_flavors
    to_delete = @data[:flavors].reject { |f| f[:enabled] || @known_flavors.include?(f[:ems_ref]) }
    to_delete.each do |f|
      @data_index[:flavors].delete(f[:ems_ref])
      @data[:flavors].delete(f)
    end
  end

  ARCHITECTURE_TO_BITNESS = {
    :i386   => 32,
    :x86_64 => 64,
  }.freeze

  def architecture_to_bitness(arch)
    ARCHITECTURE_TO_BITNESS[arch.to_sym]
  end

  def get_from_tags(resource, tag_name)
    tag_name = tag_name.to_s.downcase
    resource.tags.detect { |tag, _| tag.key.downcase == tag_name }.try(:value).presence
  end

  def add_instance_disk(disks, size, location, name, controller_type = "amazon")
    if size >= 0
      disk = {
        :device_name     => name,
        :device_type     => "disk",
        :controller_type => controller_type,
        :location        => location,
        :size            => size
      }
      disks << disk
      return disk
    end
    nil
  end

  def add_block_device_disk(disks, name, location)
    disk = {
      :device_name     => name,
      :device_type     => "disk",
      :controller_type => "amazon",
      :location        => location,
    }
    disks << disk
    disk
  end

  # Compose an ems_ref combining some existing keys
  def compose_ems_ref(*keys)
    keys.join('_')
  end

  module ClassMethods
    def ems_inv_to_hashes(ems, options = nil)
      new(ems, options).ems_inv_to_hashes
    end
  end
end
