module ManageIQ::Providers::Amazon::ManagerMixin
  extend ActiveSupport::Concern

  included do
    validates :provider_region, :inclusion => {:in => ManageIQ::Providers::Amazon::Regions.names}
  end

  def description
    ManageIQ::Providers::Amazon::Regions.find_by_name(provider_region)[:description]
  end

  def browser_url
    "https://console.aws.amazon.com/ec2/v2/home?region=#{provider_region}"
  end

  def validate_timeline
    {:available => false,
     :message   => _("Timeline is not available for %{model}") % {:model => ui_lookup(:model => self.class.to_s)}}
  end

  # manually add s3 manager to list of storage managers
  def storage_managers
    return super << provider.s3_storage_manager if provider.s3_storage_manager
    super
  end

  def connect(options = {})
    options[:provider_region] = provider_region
    provider.connect(options)
  end

  module ClassMethods

    def raw_connect(*args, &block)
      ManageIQ::Providers::Amazon::Provider::raw_connect(*args, &block)
    end

    #
    # Discovery
    #

    # Factory method to create EmsAmazon instances for all regions with instances
    #   or images for the given authentication.  Created EmsAmazon instances
    #   will automatically have EmsRefreshes queued up.  If this is a greenfield
    #   discovery, we will at least add an EmsAmazon for us-east-1
    def discover(access_key_id, secret_access_key)
      new_emses         = []
      all_emses         = includes(:authentications)
      all_ems_names     = all_emses.map(&:name).to_set
      known_ems_regions = all_emses.select { |e| e.authentication_userid == access_key_id }.map(&:provider_region)

      ec2 = raw_connect(access_key_id, secret_access_key, :EC2, "us-east-1")
      region_names_to_discover = ec2.client.describe_regions.regions.map(&:region_name)

      (region_names_to_discover - known_ems_regions).each do |region_name|
        ec2_region = raw_connect(access_key_id, secret_access_key, :EC2, region_name)
        next if ec2_region.instances.count == 0 && # instances
                ec2_region.images(:owners => %w(self)).count == 0 && # private images
                ec2_region.images(:executable_users => %w(self)).count == 0 # shared  images
        new_emses << create_discovered_region(region_name, access_key_id, secret_access_key, all_ems_names)
      end

      # If greenfield Amazon, at least create the us-east-1 region.
      if new_emses.blank? && known_ems_regions.blank?
        new_emses << create_discovered_region("us-east-1", access_key_id, secret_access_key, all_ems_names)
      end

      EmsRefresh.queue_refresh(new_emses) unless new_emses.blank?

      new_emses
    end

    def discover_queue(access_key_id, secret_access_key)
      MiqQueue.put(
        :class_name  => name,
        :method_name => "discover_from_queue",
        :args        => [access_key_id, MiqPassword.encrypt(secret_access_key)]
      )
    end

    private

    def discover_from_queue(access_key_id, secret_access_key)
      discover(access_key_id, MiqPassword.decrypt(secret_access_key))
    end

    def create_discovered_region(region_name, access_key_id, secret_access_key, all_ems_names)
      name = region_name
      name = "#{region_name} #{access_key_id}" if all_ems_names.include?(name)
      while all_ems_names.include?(name)
        name_counter = name_counter.to_i + 1 if defined?(name_counter)
        name = "#{region_name} #{name_counter}"
      end

      new_ems = create!(
        :name            => name,
        :provider_region => region_name,
        :zone            => Zone.default_zone
      )
      new_ems.update_authentication(
        :default => {
          :userid   => access_key_id,
          :password => secret_access_key
        }
      )

      new_ems
    end
  end
end
