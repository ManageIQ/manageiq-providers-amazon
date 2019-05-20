module ManageIQ::Providers::Amazon::ManagerMixin
  extend ActiveSupport::Concern

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
    auth_type = options[:auth_type]
    raise "no credentials defined" if missing_credentials?(auth_type)

    username    = options[:user] || authentication_userid(auth_type)
    password    = options[:pass] || authentication_password(auth_type)
    service     = options[:service] || :EC2
    proxy       = options[:proxy_uri] || http_proxy_uri
    region      = options[:region] || provider_region
    assume_role = options[:assume_role] || authentication_service_account(auth_type)

    self.class.raw_connect(username, password, service, region, proxy,
                           :assume_role => assume_role)
  end

  def verify_credentials(auth_type = nil, options = {})
    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(auth_type)

    return true if auth_type == "smartstate_docker"
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

    def raw_connect(access_key_id, secret_access_key, service, region,
                    proxy_uri = nil, validate = false, uri = nil, assume_role: nil)

      require 'aws-sdk'
      require 'patches/aws-sdk-core/seahorse_client_net_http_pool_patch'

      log_formatter_pattern = Aws::Log::Formatter.default.pattern.chomp
      secret_access_key     = ManageIQ::Password.try_decrypt(secret_access_key)

      options = {
        :credentials   => Aws::Credentials.new(access_key_id, secret_access_key),
        :region        => region,
        :http_proxy    => proxy_uri,
        :logger        => $aws_log,
        :log_level     => :debug,
        :log_formatter => Aws::Log::Formatter.new(log_formatter_pattern),
      }

      options[:endpoint] = uri.to_s if uri.to_s.present?

      if assume_role
        options[:credentials] = Aws::AssumeRoleCredentials.new(
          :client            => Aws::STS::Client.new(options),
          :role_arn          => assume_role,
          :role_session_name => "ManageIQ-#{service}",
        )
      end

      connection = Aws.const_get(service)::Resource.new(options)

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
      require 'patches/aws-sdk-core/seahorse_client_net_http_pool_patch'
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
  end
end
