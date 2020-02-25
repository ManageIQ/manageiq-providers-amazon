class ManageIQ::Providers::Amazon::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :AuthKeyPair
  require_nested :AvailabilityZone
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :Flavor
  require_nested :MetricsCapture
  require_nested :MetricsCollectorWorker
  require_nested :OrchestrationServiceOptionConverter
  require_nested :OrchestrationStack
  require_nested :OrchestrationTemplate
  require_nested :Provision
  require_nested :ProvisionWorkflow
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :Scanning
  require_nested :Template
  require_nested :Vm

  OrchestrationTemplate.register_eligible_manager(self)

  include ManageIQ::Providers::Amazon::ManagerMixin

  has_one :network_manager,
          :foreign_key => :parent_ems_id,
          :class_name  => "ManageIQ::Providers::Amazon::NetworkManager",
          :autosave    => true

  has_many :storage_managers,
           :foreign_key => :parent_ems_id,
           :class_name  => "ManageIQ::Providers::StorageManager",
           :autosave    => true

  delegate :floating_ips,
           :security_groups,
           :cloud_networks,
           :cloud_subnets,
           :network_ports,
           :network_routers,
           :public_networks,
           :private_networks,
           :all_cloud_networks,
           :to        => :network_manager,
           :allow_nil => true

  has_one :ebs_storage_manager,
          :foreign_key => :parent_ems_id,
          :class_name  => "ManageIQ::Providers::Amazon::StorageManager::Ebs",
          :autosave    => true,
          :dependent   => :destroy

  delegate :cloud_volumes,
           :cloud_volume_snapshots,
           :to        => :ebs_storage_manager,
           :allow_nil => true

  has_one :s3_storage_manager,
          :foreign_key => :parent_ems_id,
          :class_name  => "ManageIQ::Providers::Amazon::StorageManager::S3",
          :autosave    => true,
          :dependent   => :destroy

  delegate :cloud_object_store_containers,
           :cloud_object_store_objects,
           :to        => :s3_storage_manager,
           :allow_nil => true

  before_create :ensure_managers
  before_update :ensure_managers_zone_and_provider_region

  supports :provisioning
  supports :regions
  supports :assume_role

  def ensure_managers
    build_network_manager unless network_manager
    network_manager.name = "#{name} Network Manager"

    build_ebs_storage_manager unless ebs_storage_manager
    ebs_storage_manager.name = "#{name} EBS Storage Manager"

    if ::Settings.prototype.amazon.s3
      build_s3_storage_manager unless s3_storage_manager
      s3_storage_manager.name = "#{name} S3 Storage Manager"
    end

    ensure_managers_zone_and_provider_region
  end

  def ensure_managers_zone_and_provider_region
    if network_manager
      network_manager.zone_id         = zone_id
      network_manager.provider_region = provider_region
    end

    if ebs_storage_manager
      ebs_storage_manager.zone_id         = zone_id
      ebs_storage_manager.provider_region = provider_region
    end

    if s3_storage_manager
      s3_storage_manager.zone_id         = zone_id
      s3_storage_manager.provider_region = provider_region
    end
  end

  def self.ems_type
    @ems_type ||= "ec2".freeze
  end

  def self.description
    @description ||= "Amazon EC2".freeze
  end

  def self.hostname_required?
    false
  end

  def self.default_blacklisted_event_names
    Settings.ems.ems_amazon.blacklisted_event_names
  end

  def self.params_for_create
    @params_for_create ||= {
      :fields => [
        {
          :component  => "select-field",
          :name       => "provider_region",
          :label      => _("Region"),
          :isRequired => true,
          :validate   => [{:type => "required-validator"}],
          :options    => ManageIQ::Providers::Amazon::Regions.all.sort_by { |r| r[:description] }.map do |region|
            {
              :label => region[:description],
              :value => region[:name]
            }
          end
        },
        {
          :component => 'sub-form',
          :name      => 'endpoints',
          :title     => _("Endpoint"),
          :fields    => [
            {
              :component              => 'validate-provider-credentials',
              :name                   => 'authentications.default.valid',
              :validationDependencies => %w[type zone_name provider_region],
              :fields                 => [
                {
                  :component => "text-field",
                  :name      => "endpoints.default.url",
                  :label     => _("Endpoint URL"),
                },
                {
                  :component => "text-field",
                  :name      => "authentications.default.service_account",
                  :label     => _("Assume role ARN"),
                },
                {
                  :component  => "text-field",
                  :name       => "authentications.default.userid",
                  :label      => _("Access Key ID"),
                  :helperText => _("Should have privileged access, such as root or administrator."),
                  :isRequired => true,
                  :validate   => [{:type => "required-validator"}]
                },
                {
                  :component  => "password-field",
                  :name       => "authentications.default.password",
                  :label      => _("Secret Access Key"),
                  :type       => "password",
                  :isRequired => true,
                  :validate   => [{:type => "required-validator"}]
                },
              ],
            },
          ],
        },
      ],
    }.freeze
  end

  def self.create_from_params(params)
    endpoints = params.delete("endpoints")
    authentications = params.delete("authentications")

    params[:zone] = Zone.find_by(:name => params.delete("zone_name"))
    new(params).tap do |ems|
      endpoints.each do |authtype, endpoint|
        url = endpoint.delete("url")
        ems.endpoints.new(:role => authtype, :url => url)
      end

      authentications.each do |authtype, authentication|
        ems.authentications.new(authentication.merge(:authtype => authtype))
      end

      ems.save!
    end
  end

  def supported_auth_types
    %w(default smartstate_docker)
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  def supported_catalog_types
    %w(amazon).freeze
  end

  def inventory_object_refresh?
    true
  end

  def allow_targeted_refresh?
    true
  end

  # @param [ManageIQ::Providers::Amazon::CloudManager::OrchestrationTemplate] template
  # @return [nil] if the template is valid
  # @return [String] if the template is invalid this is the error message
  def orchestration_template_validate(template)
    with_provider_connection(:service => :CloudFormation) do |cloud_formation|
      nil if cloud_formation.client.validate_template(:template_body => template.content)
    end
  rescue Aws::CloudFormation::Errors::ValidationError => validation_error
    validation_error.message
  rescue => err
    _log.error "template=[#{template.name}], error: #{err}"
    raise MiqException::MiqOrchestrationValidationError, err.to_s, err.backtrace
  end

  def self.display_name(number = 1)
    n_('Cloud Provider (Amazon)', 'Cloud Providers (Amazon)', number)
  end
end
