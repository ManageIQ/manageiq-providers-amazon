class ManageIQ::Providers::Amazon::ContainerManager < ManageIQ::Providers::Kubernetes::ContainerManager
  require_nested :Container
  require_nested :ContainerGroup
  require_nested :ContainerNode
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :Refresher
  require_nested :RefreshWorker

  def self.ems_type
    @ems_type ||= "eks".freeze
  end

  def self.description
    @description ||= "Amazon EKS".freeze
  end

  def self.kubernetes_auth_options(options)
    auth_options = {}

    # If a user has configured a service account we should use that
    auth_options[:bearer_token] = options[:bearer] if options[:bearer].present?

    # Otherwise request a token from STS with an access_key+secret_access_key
    auth_options[:bearer_token] ||= sts_eks_token(options[:username], options[:password], options[:region_name], options[:cluster_name])

    auth_options
  end

  def self.sts_eks_token(access_key, secret_access_key, region_name, cluster_name)
    url = sts_presigned_url(access_key, secret_access_key, region_name, cluster_name)

    "k8s-aws-v1.#{Base64.urlsafe_encode64(url).sub(/=+$/, "")}"
  end
  private_class_method :sts_eks_token

  def self.sts_presigned_url(access_key, secret_access_key, region_name, cluster_name)
    require "aws-sdk-sts"
    sts_client = Aws::STS::Client.new(
      :credentials => Aws::Credentials.new(access_key, secret_access_key),
      :region      => region_name
    )

    Aws::STS::Presigner.new(:client => sts_client).get_caller_identity_presigned_url(
      :headers => {"X-K8s-Aws-Id" => cluster_name}
    )
  end
  private_class_method :sts_presigned_url

  def self.verify_credentials(args)
    # If we are editing an existing EMS we won't be given the existing passwords
    # if they aren't going to be changed
    ext_management_system = find(args["id"]) if args["id"]

    region_name  = args["provider_region"]
    cluster_name = args["uid_ems"]

    endpoint_name = args.dig("endpoints").keys.first
    endpoint      = args.dig("endpoints", endpoint_name)

    hostname, port, security_protocol, certificate_authority, _proxy_uri, _service_account = endpoint&.values_at(
      "hostname", "port", "security_protocol", "certificate_authority", "proxy_uri", "service_account"
    )

    verify_ssl = security_protocol == 'ssl-without-validation' ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER

    authentication = args.dig("authentications", "bearer")

    token, access_key, secret_access_key = authentication&.values_at(
      "auth_key", "userid", "password"
    )

    token = ManageIQ::Password.try_decrypt(token)
    token ||= ext_management_system.authentication_token("bearer") if ext_management_system

    secret_access_key = ManageIQ::Password.try_decrypt(secret_access_key)
    secret_access_key ||= ext_management_system.authentication_password("bearer") if ext_management_system

    options = {
      :username     => access_key,
      :password     => secret_access_key,
      :bearer       => token,
      :region_name  => region_name,
      :cluster_name => cluster_name,
      :ssl_options  => {
        :verify_ssl => verify_ssl,
        :ca_file    => certificate_authority
      }
    }

    case endpoint_name
    when 'default'
      !!raw_connect(hostname, port, options)
    else
      raise MiqException::MiqInvalidCredentialsError, _("Unsupported endpoint")
    end
  end

  def connect_options(options = {})
    super.merge(
      :region_name  => provider_region,
      :cluster_name => uid_ems
    )
  end
end
