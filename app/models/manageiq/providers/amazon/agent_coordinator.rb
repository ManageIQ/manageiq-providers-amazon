require 'yaml'
require 'open3'
require 'net/scp'
require 'tempfile'
require 'linux_admin'
require 'awesome_spawn'
require 'amazon_ssa_support'

class ManageIQ::Providers::Amazon::AgentCoordinator
  include Vmdb::Logging
  include ScanningMixin
  attr_accessor :ems, :deploying

  SSA_LABEL = "smartstate".freeze
  WORK_DIR  = "/opt/ssa_container".freeze

  def initialize(ems)
    @ems = ems

    # List of active agent ids
    @alive_agent_ids = []

    # List of all agent ids, include those in power off state.
    @agent_ids = []
    @deploying = false
  end

  def ec2
    @ec2 ||= ems.connect(:service => 'EC2')
  end

  def sqs
    @sqs ||= ems.connect(:service => 'SQS')
  end

  def s3
    @s3 ||= ems.connect(:service => 'S3')
  end

  def iam
    @iam ||= ems.connect(:service => 'IAM')
  end

  def alive_agent_ids(interval = 180)
    @alive_agent_ids = agent_ids.select { |id| agent_alive?(id, interval) }
  end

  def request_queue_empty?
    messages_in_queue(request_queue).zero?
  end

  def reply_queue_empty?
    messages_in_queue(reply_queue).zero?
  end

  def deploying?
    @deploying
  end

  def startup_agent
    agent_ids.empty? ? deploy_agent : activate_agents
  rescue => err
    _log.error("No agent is set up to process requests: #{err.message}")
    cleanup_requests(err.message)
  end

  def cleanup_requests(message)
    _log.info("Cleaning up outstanding requests due to Agent deployment error")
    if request_queue_empty?
      _log.debug("No requests visible for provider #{ems.name}")
    else
      @ssaq = ssa_queue
      _log.debug("Getting requests for #{ems.name}")
      @ssaq.request_loop do |request|
        begin
          _log.debug("Request for #{ems.name}: #{request}")
          clean_request(request, message)
        rescue => err
          _log.error("Error #{err} cleaning requests for #{ems.name}. Continuing.")
          next
        end
      end
    end
  end

  def clean_request(request, message)
    @ssaq.delete_request(request)
    ost       = OpenStruct.new
    ost.jobid = request[:job_id]
    job       = Job.find_by(:id =>ost.jobid)
    raise "Unable to clean request for job with id #{ost.jobid}" if job.nil?
    target_id  = job.target_id
    vm         = VmOrTemplate.find(target_id)
    ost.taskid = job.guid
    unless vm.kind_of?(ManageIQ::Providers::Amazon::CloudManager::Vm) ||
           vm.kind_of?(ManageIQ::Providers::Amazon::CloudManager::Template)
      if vm.nil?
        error = "Vm for Job #{ost.jobid} not found"
      else
        error = "Vm #{vm.name} of class #{vm.class.name} is not an Amazon instance or image" unless vm.nil?
      end
      update_job_message(ost, error)
      job.signal(:abort, error, "error")
      return
    end
    _log.debug("Cleaning request for #{vm.ems_ref} because #{message}")
    update_job_message(ost, message)
    job.signal(:abort, message, "error")
  end

  def cleanup_agents
    _log.info("Clean up agents ...")

    # Use the uniqe keypair name to filter out created instances
    vms = ec2.instances(
      :filters => [
        {
          :name   => "key-name",
          :values => [default_keypair_name],
        },
        {
          :name   => "instance-state-name",
          # skip the state of 'terminated'
          :values => ["pending", "running", "shutting-down", "stopping", "stopped"],
        },
      ]
    )

    vms.each do |vm|
      next if agent_ids.include?(vm.id)
      vm.terminate
      vm.wait_until_terminated
      _log.info("Instance: #{vm.id} is deleted!")
    end
  end

  def ssa_queue
    AmazonSsaSupport::SsaQueue.new(
      :ssa_bucket    => ssa_bucket,
      :reply_queue   => reply_queue,
      :request_queue => request_queue,
      :region        => ems.provider_region,
      :sqs           => sqs,
      :s3            => s3
    )
  end

  private

  def scp_file(ip, username, auth_key, local_file, remote_file)
    Net::SCP.upload!(ip, username, local_file, remote_file, :ssh => {:key_data => auth_key})
  rescue => err
    _log.error(err.message)
    raise("Failed to copy #{local_file} to #{ip}:#{remote_file}")
  end

  def agent_ids
    # reset to empty
    @agent_ids = []

    bucket = s3.bucket(ssa_bucket)
    return @agent_ids unless bucket.exists?

    bucket.objects(:prefix => heartbeat_prefix).each do |obj|
      id = obj.key.split('/')[2]
      @agent_ids << id if ec2.instance(id).exists?
    end

    @agent_ids
  end

  # check timestamp of heartbeat of agent_id, return true if the last beat time in
  # in the time interval
  def agent_alive?(agent_id, interval = 180)
    bucket = s3.bucket(ssa_bucket)
    return false unless bucket.exists?

    obj_id = "#{heartbeat_prefix}#{agent_id}"
    obj = bucket.object(obj_id)
    return false unless obj.exists?

    last_heartbeat = obj.last_modified
    _log.debug("#{obj.key}: Last heartbeat time stamp: #{last_heartbeat}")

    Time.now.utc - last_heartbeat < interval && ec2.instance(agent_id).state.name == "running"
  rescue => err
    _log.error("#{agent_id}: #{err.message}")
    false
  end

  def activate_agents
    agent_ids.each do |id|
      agent = ec2.instance(id)
      if agent.state.name == "stopped"
        agent.start
        agent.wait_until_running
        _log.info("Agent #{id} is activated to serve requests.")
        return id
      elsif agent.state.name == "running"
        _log.info("Agent #{id} is running already.")
        return id
      else
        _log.warn("Agent #{id} is in abnormal state: #{agent.state.name}.")
        next
      end
    end

    _log.warn("Failed to activate agents: #{agent_ids}. Will deploy a new agent!")
    deploy_agent
  end

  def deploy_agent
    _log.info("Deploying agent ...")
    @deploying = true

    kp = find_or_create_keypair
    subnet = get_subnet_from_vpc_zone

    # Use the first qualified subnet to deploy agent.
    vpc_id = subnet.vpc_id
    zone_name = subnet.availability_zone
    subnet_id = subnet.subnet_id

    _log.info("Smartstate agent will be deployed in vpc: [#{vpc_id}], zone: [#{zone_name}] subnet: [#{subnet_id}]")

    security_group_id = find_or_create_security_group(vpc_id)
    find_or_create_profile

    # Based on Amazon doc, add a retry logic in creating instance to solve time issue on IAM role.
    #
    # Important
    #
    # After you create an IAM role, it may take several seconds for the permissions to propagate.
    # If your first attempt to launch an instance with a role fails, wait a few seconds before trying again.
    # For more information, see Troubleshooting Working with Roles in the IAM User Guide.
    #
    # (https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html#launch-instance-with-role-console)

    max_retries = 5
    begin
      instance = ec2.create_instances(
        :iam_instance_profile => {:name => label},
        :image_id             => get_agent_image_id,
        :instance_type        => 't2.micro',
        :key_name             => kp.name,
        :max_count            => 1,
        :min_count            => 1,
        :placement            => {:availability_zone => zone_name},
        :tag_specifications   => [{:resource_type => "instance", :tags => [{:key => "Name", :value => label}]}],
        :network_interfaces   => [{
          :associate_public_ip_address => true,
          :delete_on_termination       => true,
          :device_index                => 0,
          :subnet_id                   => subnet_id,
          :groups                      => [security_group_id]
        }],
      ).first
    rescue Aws::EC2::Errors::InvalidParameterValue => e
      if max_retries.positive?
        sleep 5
        max_retries -= 1
        _log.warn("Will retry #{max_retries} times due to error: #{e.message}")
        retry
      else
        raise "Failed to create instance. Reason: #{e.message}"
      end
    end

    ec2.client.wait_until(:instance_status_ok, :instance_ids => [instance.id])

    _log.info("Start to load smartstate application, this may take a while ...")

    setup_agent(instance)
    _log.info("Docker #{docker_image} is loaded. Start to heartbeat.")

    instance.id
  rescue => err
    _log.error(err.message)
    instance&.terminate
    instance&.wait_until_terminated
    raise
  end

  def setup_agent(instance)
    # Somehow instance.public_dns_name is empty, need to reinitialize to get it back
    ip = ec2.instance(instance.id).public_dns_name || raise("Failed to get agent's public ip!")
    key_name = instance.key_name
    auth_key = get_keypair(key_name).try(:auth_key)
    raise("Key [#{key_name}] is missing. Cannot SSH to the agent:#{instance.id}") if auth_key.nil?

    ssh = LinuxAdmin::SSH.new(ip, agent_ami_login_user, auth_key)

    # prepare work directory
    perform_commands(ssh, ["sudo mkdir -p #{WORK_DIR}", "sudo chmod go+w #{WORK_DIR}"])

    # scp the default setting yaml file
    config = Tempfile.new('config.yml')
    begin
      config.write(create_config_yaml)
      config.close
      scp_file(ip, agent_ami_login_user, auth_key, config.path, "#{WORK_DIR}/config.yml")
    ensure
      config.unlink
    end

    # docker register
    if docker_login_required?
      raise("Need credentials to login") unless docker_auth

      docker_username = docker_auth.userid
      docker_password = docker_auth.password

      login_params = [
        docker_registry,
        {
          :u => docker_username,
          :p => docker_password
        }
      ]
      login_cmd = AwesomeSpawn.build_command_line("sudo docker login", login_params)

      perform_commands(ssh, [login_cmd])
    end

    # run docker image
    image = docker_registry.present? ? "#{docker_registry}/#{docker_image}" : docker_image
    run_params = [
      :d,
      {:restart => "always"},
      ['-v', '/dev:/host_dev'],
      ['-v', "#{WORK_DIR}/config.yml:#{WORK_DIR}/config.yml"],
      :privileged,
      image
    ]
    run_cmd = AwesomeSpawn.build_command_line("sudo docker run", run_params)
    perform_commands(ssh, [run_cmd])
  end

  def perform_commands(ssh, commands)
    _log.debug("SSH commands: #{commands}")
    result = ssh.perform_commands(commands)

    unless result[:exit_status].zero?
      _log.error("Failed to run command: #{result[:last_command]}")
      raise("SSH failed to run command: #{result[:last_command]}")
    end
  end

  def docker_auth
    @ems.authentications.find_by(:authtype => "smartstate_docker")
  end

  def get_subnet_from_vpc_zone
    vpcs = validated_vpcs
    raise "Smartstate analysis needs a VPC whose enableDnsSupport/enableDnsHostnames settings are true!" if vpcs.empty?

    ec2.client.describe_availability_zones.availability_zones.each do |availability_zone|
      vpcs.each do |vpc|
        subnet = get_subnets(availability_zone.zone_name, vpc.vpc_id).try(:first)
        return subnet if subnet
      end
    end
    raise("No subnet is qualified to deploy smartstate agent!")
  end

  # To run SSA, VPC needs to have gateway attached, enableDnsSupport and enableDnsHostnames are enabled
  def validated_vpcs
    ec2.vpcs.select do |vpc|
      enabled_dns_support?(vpc) && enabled_dns_hostnames?(vpc) && enabled_internet_gateways?(vpc)
    end
  end

  def enabled_dns_hostnames?(vpc)
    vpc.describe_attribute(:attribute => 'enableDnsHostnames', :vpc_id => vpc.vpc_id).enable_dns_hostnames.value
  end

  def enabled_dns_support?(vpc)
    vpc.describe_attribute(:attribute => 'enableDnsSupport', :vpc_id => vpc.vpc_id).enable_dns_support.value
  end

  def enabled_internet_gateways?(vpc)
    igw_ids = vpc.internet_gateways.map(&:internet_gateway_id)

    unless igw_ids.empty? # Gateway attached
      _log.debug("Found a gateway [#{igw_ids.first}] on VPC [#{vpc.id}]")

      # Make sure gateway has vaild route
      route_tables = vpc.route_tables.select do |route_table|
        route_table.routes.any? { |route| route.gateway_id == igw_ids.first }
      end

      unless route_tables.empty?
        _log.debug("Found route tables #{route_tables} on the gateway [#{igw_ids.first}]")
        subnets = route_tables.map { |rt| rt.associations.first.subnet_id }

        # Now the gateway is proved to have associated route and subnet
        return true if subnets.any?
      end
    end

    false
  end

  # Get Key Pair for SSH. Create a new one if not exists.
  def find_or_create_keypair(keypair_name = default_keypair_name)
    get_keypair(keypair_name) || begin
      _log.info("KeyPair #{keypair_name} will be created!")
      # Delete from Aws if existing
      ec2.key_pair(keypair_name).try(:delete)
      ManageIQ::Providers::CloudManager::AuthKeyPair.create_key_pair(@ems.id, :name => keypair_name)
    end
  end

  def get_keypair(keypair_name = label)
    @ems.authentications.find_by(:name => keypair_name)
  end

  def find_or_create_profile(profile_name = label, role_name = label)
    ssa_profile = iam.instance_profile(profile_name)
    ssa_profile = iam.create_instance_profile(:instance_profile_name => profile_name) unless ssa_profile.exists?
    ssa_profile.wait_until_exists

    find_or_create_role(role_name)
    ssa_profile.add_role(:role_name => role_name) if ssa_profile.roles.empty?

    ssa_profile
  end

  def find_or_create_role(role_name = label)
    return iam.role(role_name) if role_exists?(role_name)

    # Policy Generator:
    policy_doc = {
      :Version   => "2012-10-17",
      :Statement => [
        {
          :Effect    => "Allow",
          :Principal => { :Service => "ec2.amazonaws.com" },
          :Action    => "sts:AssumeRole"
        }
      ]
    }

    role = iam.create_role(
      :role_name                   => role_name,
      :assume_role_policy_document => policy_doc.to_json
    )

    # grant all priviledges
    %w(AmazonS3FullAccess AmazonEC2FullAccess AmazonSQSFullAccess).each do |policy|
      role.attach_policy(:policy_arn => "arn:aws:iam::aws:policy/#{policy}")
    end

    role
  end

  def role_exists?(role_name)
    !!iam.role(role_name).role_id
  rescue ::Aws::IAM::Errors::NoSuchEntity
    false
  end

  def find_or_create_security_group(vpc_id = nil, group_name = label)
    security_group = ec2.client.describe_security_groups(
      :filters => [{
        :name   => "group-name",
        :values => [group_name]
      }]
    ).security_groups.first
    return security_group.group_id unless security_group.nil?

    # create security group if not exist
    security_group = ec2.create_security_group(
      :group_name  => group_name,
      :description => 'Security group for smartstate Agent',
      :vpc_id      => vpc_id
    )

    security_group.authorize_ingress(
      :ip_permissions => [{
        :ip_protocol => 'tcp',
        :from_port   => 22,
        :to_port     => 22,
        :ip_ranges   => [{
          :cidr_ip => '0.0.0.0/0'
        }]
      }]
    )

    security_group.authorize_ingress(
      :ip_permissions => [{
        :ip_protocol => 'tcp',
        :from_port   => 80,
        :to_port     => 80,
        :ip_ranges   => [{
          :cidr_ip => '0.0.0.0/0'
        }]
      }]
    )

    security_group.authorize_ingress(
      :ip_permissions => [{
        :ip_protocol => 'tcp',
        :from_port   => 443,
        :to_port     => 443,
        :ip_ranges   => [{
          :cidr_ip => '0.0.0.0/0'
        }]
      }]
    )

    security_group.group_id
  end

  def get_subnets(az, vpc_id)
    ec2.client.describe_subnets(
      :filters => [
        {
          :name   => "availability-zone",
          :values => [az]
        },
        {
          :name   => "vpc-id",
          :values => [vpc_id]
        }
      ]
    ).subnets
  end

  # possible RHEL image name: values: [ "RHEL-7.3_HVM_GA*" ]
  def get_agent_image_id(image_name = agent_ami_name)
    image = ec2.client.describe_images(
      :filters => [{
        :name   => "name",
        :values => [image_name]
      }]
    ).images.first
    raise("Unable to find AMI Image #{image_name} to launch Smartstate agent") if image.nil?

    _log.info("AMI Image: #{image_name} [#{image.image_id}] is used to launch smartstate agent.")

    image.image_id
  end

  def create_pem_file(pair_name = default_keypair_name)
    keypair = find_or_create_keypair(pair_name)
    pem_file_name = "#{pair_name}.pem"
    File.write(pem_file_name, keypair.auth_key)
    File.chmod(0o400, pem_file_name)
    pem_file_name
  end

  def create_config_yaml
    defaults = agent_coordinator_settings.to_hash.except(:agent_ami_name, :docker_image, :agent_label, :agent_ami_login_user, :docker_login_required, :response_thread_sleep_seconds)
    defaults[:reply_queue]   = reply_queue
    defaults[:request_queue] = request_queue
    defaults[:ssa_bucket]    = ssa_bucket
    defaults[:log_prefix] = log_prefix

    defaults.to_yaml
  end

  def messages_in_queue(q_name)
    q = sqs.get_queue_by_name(:queue_name => q_name)
    q.attributes["ApproximateNumberOfMessages"].to_i + q.attributes["ApproximateNumberOfMessagesNotVisible"].to_i
  rescue
    0
  end

  def agent_coordinator_settings
    @agent_coordinator_settings ||= Settings.ems.ems_amazon.agent_coordinator
  end

  def region
    @ems.provider_region
  end

  def agent_log_level
    ll = agent_coordinator_settings.try(:log_level) || AmazonSsaSupport::DEFAULT_LOG_LEVEL
    ll.upcase
  end

  def heartbeat_prefix
    AmazonSsaSupport::DEFAULT_HEARTBEAT_PREFIX
  end

  def heartbeat_interval
    agent_coordinator_settings.try(:heartbeat_interval) || AmazonSsaSupport::DEFAULT_HEARTBEAT_INTERVAL
  end

  def ssa_bucket
    @ssa_bucket ||= "#{AmazonSsaSupport::DEFAULT_BUCKET_PREFIX}-#{@ems.guid}".freeze
  end

  def request_queue
    @request_queue ||= "#{AmazonSsaSupport::DEFAULT_REQUEST_QUEUE}-#{@ems.guid}".freeze
  end

  def reply_queue
    @reply_queue ||= "#{AmazonSsaSupport::DEFAULT_REPLY_QUEUE}-#{@ems.guid}".freeze
  end

  def default_keypair_name
    "#{label}-#{@ems.guid}".freeze
  end

  def reply_prefix
    AmazonSsaSupport::DEFAULT_REPLY_PREFIX
  end

  def log_prefix
    AmazonSsaSupport::DEFAULT_LOG_PREFIX
  end

  def agent_ami_name
    agent_coordinator_settings.try(:agent_ami_name) || raise("Please specify AMI image name for smartstate agent")
  end

  def agent_ami_login_user
    agent_coordinator_settings.try(:agent_ami_login_user) || raise("Please specify AMI image's login user name for smartstate agent")
  end

  def docker_image
    agent_coordinator_settings.try(:docker_image) || raise("Please specify docker image name for smartstate agent")
  end

  def docker_registry
    agent_coordinator_settings.try(:docker_registry)
  end

  def docker_login_required?
    agent_coordinator_settings.try(:docker_login_required)
  end

  # This label is used to name all objects (profile/role/instance, etc) we created in AWS.
  # Make it configurable for upstream/downstream name conventions
  def label
    @label ||= agent_coordinator_settings.try(:agent_label) || SSA_LABEL
  end
end
