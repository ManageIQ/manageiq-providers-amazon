ManageIQ::Providers::Kubernetes::ContainerManager.include(ActsAsStiLeafClass)

class ManageIQ::Providers::Amazon::ContainerManager < ManageIQ::Providers::Kubernetes::ContainerManager
  require_nested :Container
  require_nested :ContainerGroup
  require_nested :ContainerImage
  require_nested :ContainerNode
  require_nested :ContainerTemplate
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :Refresher
  require_nested :RefreshWorker
  require_nested :ServiceInstance
  require_nested :ServiceOffering
  require_nested :ServiceParametersSet

  supports :create

  def self.ems_type
    @ems_type ||= "eks".freeze
  end

  def self.description
    @description ||= "Amazon EKS".freeze
  end

  def self.display_name(number = 1)
    n_('Container Provider (Amazon)', 'Container Providers (Amazon)', number)
  end

  def self.default_port
    443
  end

  def self.kubernetes_auth_options(options)
    auth_options = {}

    # If a user has configured a service account we should use that
    auth_options[:bearer_token] = options[:bearer] if options[:bearer].present?

    # Otherwise request a token from STS with an access_key+secret_access_key
    auth_options[:bearer_token] ||= sts_eks_token(options[:username], options[:password], options[:cluster_name])

    auth_options
  end

  def self.sts_eks_token(access_key, secret_access_key, cluster_name)
    require "kubeclient/aws_eks_credentials"
    require "aws-sdk-sts"

    credentials = Aws::Credentials.new(access_key, secret_access_key)

    Kubeclient::AmazonEksCredentials.token(credentials, cluster_name)
  end
  private_class_method :sts_eks_token

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

    authentication = args.dig("authentications", "default")

    token, access_key, secret_access_key = authentication&.values_at(
      "auth_key", "userid", "password"
    )

    token = ManageIQ::Password.try_decrypt(token)
    token ||= ext_management_system.authentication_token("default") if ext_management_system

    secret_access_key = ManageIQ::Password.try_decrypt(secret_access_key)
    secret_access_key ||= ext_management_system.authentication_password("default") if ext_management_system

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

  private_class_method def self.provider_region_options
    ManageIQ::Providers::Amazon::Regions
      .all
      .sort_by { |r| r[:description].downcase }
      .map do |r|
        {
          :label => r[:description],
          :value => r[:name]
        }
      end
  end

  def self.params_for_create
    {
      :fields => [
        {
          :component    => "select",
          :id           => "provider_region",
          :name         => "provider_region",
          :label        => _("Region"),
          :isRequired   => true,
          :includeEmpty => true,
          :validate     => [{:type => "required"}],
          :options      => provider_region_options
        },
        {
          :component  => "text-field",
          :id         => "uid_ems",
          :name       => "uid_ems",
          :label      => _("Cluster Name"),
          :isRequired => true,
          :validate   => [{:type => "required"}]
        },
        {
          :component => 'sub-form',
          :id        => 'endpoints-subform',
          :name      => 'endpoints-subform',
          :title     => _('Endpoints'),
          :fields    => [
            :component => 'tabs',
            :name      => 'tabs',
            :fields    => [
              {
                :component => 'tab-item',
                :id        => 'default-tab',
                :name      => 'default-tab',
                :title     => _('Default'),
                :fields    => [
                  {
                    :component              => 'validate-provider-credentials',
                    :id                     => 'authentications.default.valid',
                    :name                   => 'authentications.default.valid',
                    :skipSubmit             => true,
                    :isRequired             => true,
                    :validationDependencies => %w[type zone_id provider_region uid_ems],
                    :fields                 => [
                      {
                        :component    => "select",
                        :id           => "endpoints.default.security_protocol",
                        :name         => "endpoints.default.security_protocol",
                        :label        => _("Security Protocol"),
                        :isRequired   => true,
                        :validate     => [{:type => "required"}],
                        :initialValue => 'ssl-with-validation',
                        :options      => [
                          {
                            :label => _("SSL"),
                            :value => "ssl-with-validation"
                          },
                          {
                            :label => _("SSL trusting custom CA"),
                            :value => "ssl-with-validation-custom-ca"
                          },
                          {
                            :label => _("SSL without validation"),
                            :value => "ssl-without-validation",
                          },
                        ]
                      },
                      {
                        :component  => "text-field",
                        :id         => "endpoints.default.hostname",
                        :name       => "endpoints.default.hostname",
                        :label      => _("Hostname (or IPv4 or IPv6 address)"),
                        :isRequired => true,
                        :validate   => [{:type => "required"}],
                      },
                      {
                        :component    => "text-field",
                        :id           => "endpoints.default.port",
                        :name         => "endpoints.default.port",
                        :label        => _("API Port"),
                        :type         => "number",
                        :initialValue => default_port,
                        :isRequired   => true,
                        :validate     => [{:type => "required"}],
                      },
                      {
                        :component  => "textarea",
                        :id         => "endpoints.default.certificate_authority",
                        :name       => "endpoints.default.certificate_authority",
                        :label      => _("Trusted CA Certificates"),
                        :rows       => 10,
                        :isRequired => true,
                        :validate   => [{:type => "required"}],
                        :condition  => {
                          :when => 'endpoints.default.security_protocol',
                          :is   => 'ssl-with-validation-custom-ca',
                        },
                      },
                      {
                        :component  => "text-field",
                        :id         => "authentications.default.userid",
                        :name       => "authentications.default.userid",
                        :label      => _("Access Key ID"),
                        :helperText => _("Should have privileged access, such as root or administrator."),
                        :isRequired => true,
                        :validate   => [{:type => "required"}]
                      },
                      {
                        :component  => "password-field",
                        :id         => "authentications.default.password",
                        :name       => "authentications.default.password",
                        :label      => _("Secret Access Key"),
                        :type       => "password",
                        :isRequired => true,
                        :validate   => [{:type => "required"}]
                      },
                    ]
                  }
                ]
              }
            ]
          ]
        }
      ]
    }
  end

  # The kubernetes provider uses the bearer authtype but the primary method
  # of authenticating to EKS will be with default authtype
  def default_authentication_type
    :default
  end

  # We still want to be able to support bearer authentication if someone does
  # create a service account token
  def authentications_to_validate
    has_authentication_type?(:bearer) ? %i[bearer] : %i[default]
  end

  def required_credential_fields(type)
    type == "bearer" ? %i[bearer] : %i[userid password]
  end

  def connect_options(options = {})
    super.merge(
      :region_name  => provider_region,
      :cluster_name => uid_ems
    )
  end
end
