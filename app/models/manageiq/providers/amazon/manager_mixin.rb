module ManageIQ::Providers::Amazon::ManagerMixin
  extend ActiveSupport::Concern

  include ManageIQ::Providers::Amazon::RegionBoundManagerMixin

  included do
    validates :provider_region, :inclusion => {:in => ->(_region) { ManageIQ::Providers::Amazon::Regions.names }}
  end

  def description
    ManageIQ::Providers::Amazon::Regions.find_by_name(provider_region)[:description]
  end

  #
  # Connections
  #

  def browser_url
    "https://console.aws.amazon.com/ec2/v2/home?region=#{provider_region}"
  end

  def connect(options = {})
    raise "no credentials defined" if missing_credentials?(options[:auth_type])

    username = options[:user] || authentication_userid(options[:auth_type])
    password = options[:pass] || authentication_password(options[:auth_type])
    service  = options[:service] || :EC2
    proxy    = options[:proxy_uri] || http_proxy_uri
    region   = options[:region] || provider_region

    self.class.raw_connect(username, password, service, region, proxy)
  end

  def verify_credentials(auth_type = nil, options = {})
    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(auth_type)

    self.class.connection_rescue_block do
      # EC2 does Lazy Connections, so call a cheap function
      with_provider_connection(options.merge(:auth_type => auth_type)) do |ec2|
        self.class.validate_connection(ec2)
      end
    end

    true
  end

  module ClassMethods
    #
    # Connections
    #

    def raw_connect(access_key_id, secret_access_key, service, region, proxy_uri = nil, validate = false)
      require 'aws-sdk'

      connection = Aws.const_get(service)::Resource.new(
        :access_key_id     => access_key_id,
        :secret_access_key => MiqPassword.try_decrypt(secret_access_key),
        :region            => region,
        :http_proxy        => proxy_uri,
        :logger            => $aws_log,
        :log_level         => :debug,
        :log_formatter     => Aws::Log::Formatter.new(Aws::Log::Formatter.default.pattern.chomp)
      )

      validate_connection(connection) if validate

      connection
    end

    def validate_connection(connection)
      connection_rescue_block do
        connection.client.describe_regions.regions.map(&:region_name)
      end
    end

    def connection_rescue_block
      yield
    rescue => err
      miq_exception = translate_exception(err)
      raise unless miq_exception

      _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
      raise miq_exception
    end

    def translate_exception(err)
      require 'aws-sdk'
      case err
      when Aws::EC2::Errors::SignatureDoesNotMatch
        MiqException::MiqHostError.new "SignatureMismatch - check your AWS Secret Access Key and signing method"
      when Aws::EC2::Errors::AuthFailure
        MiqException::MiqHostError.new "Login failed due to a bad username or password."
      when Aws::Errors::MissingCredentialsError
        MiqException::MiqHostError.new "Missing credentials"
      else
        MiqException::MiqHostError.new "Unexpected response returned from system: #{err.message}"
      end
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
      default_region    = ManageIQ::Providers::Amazon::Regions.default[:name]

      ec2 = raw_connect(access_key_id, secret_access_key, :EC2, default_region)
      region_names_to_discover = ec2.client.describe_regions.regions.map(&:region_name)

      (region_names_to_discover - known_ems_regions).each do |region_name|
        ec2_region = raw_connect(access_key_id, secret_access_key, :EC2, region_name)
        next if ec2_region.instances.count == 0 && # instances
                ec2_region.images(:owners => %w(self)).count == 0 && # private images
                ec2_region.images(:executable_users => %w(self)).count == 0 # shared  images
        new_emses << create_discovered_region(region_name, access_key_id, secret_access_key, all_ems_names)
      end

      # If greenfield Amazon, at least create a default region.
      if new_emses.blank? && known_ems_regions.blank?
        new_emses << create_discovered_region(default_region,
                                                access_key_id, secret_access_key, all_ems_names)
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
  end
end
