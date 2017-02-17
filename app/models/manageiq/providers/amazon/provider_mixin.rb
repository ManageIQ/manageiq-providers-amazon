module ManageIQ::Providers::Amazon::ProviderMixin
  extend ActiveSupport::Concern

  def connect(options = {})
    raise "no credentials defined" if missing_credentials?(options[:auth_type])

    username = options[:user] || authentication_userid(options[:auth_type])
    password = options[:pass] || authentication_password(options[:auth_type])
    service  = options[:service] || :EC2
    proxy    = options[:proxy_uri] || http_proxy_uri
    region   = options[:provider_region] || "us-east-1"

    self.class.raw_connect(username, password, service, region, proxy)
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

  def verify_credentials(auth_type = nil, options = {})
    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(auth_type)

    begin
      # EC2 does Lazy Connections, so call a cheap function
      with_provider_connection(options.merge(:auth_type => auth_type)) do |ec2|
        ec2.client.describe_regions.regions.map(&:region_name)
      end
    rescue => err
      miq_exception = translate_exception(err)
      raise unless miq_exception

      _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
      raise miq_exception
    end

    true
  end

  def http_proxy_uri
    VMDB::Util.http_proxy_uri(emstype.try(:to_sym)) || VMDB::Util.http_proxy_uri
  end

  module ClassMethods
    def raw_connect(access_key_id, secret_access_key, service, region, proxy_uri = nil)
      require 'aws-sdk'
      Aws.const_get(service)::Resource.new(
        :access_key_id     => access_key_id,
        :secret_access_key => secret_access_key,
        :region            => region,
        :http_proxy        => proxy_uri,
        :logger            => $aws_log,
        :log_level         => :debug,
        :log_formatter     => Aws::Log::Formatter.new(Aws::Log::Formatter.default.pattern.chomp)
      )
    end
  end
end
