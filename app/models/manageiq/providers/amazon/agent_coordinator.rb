require 'yaml'
require 'open3'
require 'net/scp'
require 'tempfile'
require 'linux_admin'
require 'amazon_ssa_support'

class ManageIQ::Providers::Amazon::AgentCoordinator
  include Vmdb::Logging
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
    _log.error(err.backtrace.join("\n"))
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
      else
        _log.warn("Agent #{id} is in abnormal state: #{agent.state.name}.")
        next
      end
    end

    _log.error("Failed to activate agents: #{agent_ids}.")
  end

  def deploy_agent
    _log.info("Deploying agent ...")
    @deploying = true

    kp = find_or_create_keypair
    zone_name = ec2.client.describe_availability_zones.availability_zones[0].zone_name
    subnets = get_subnets(zone_name)
    raise "No subnet_id is available for #{zone_name}!" if subnets.empty?
    security_group_id = find_or_create_security_group(subnets[0].vpc_id)
    find_or_create_profile

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
        :subnet_id                   => subnets[0].subnet_id,
        :groups                      => [security_group_id]
      }],
    ).first
    ec2.client.wait_until(:instance_status_ok, :instance_ids => [instance.id])

    _log.info("Start to load smartstate application, this may take a while ...")

    setup_agent(instance)
    _log.info("Docker #{docker_image} is loaded. Start to heartbeat.")

    instance.id
  end

  def setup_agent(instance)
    # Somehow instance.public_dns_name is empty, need to reinitialize to get it back
    ip = ec2.instance(instance.id).public_dns_name || raise("Failed to get agent's public ip!")
    key_name = instance.key_name
    auth_key = get_keypair(key_name).try(:auth_key)
    _log.error("Key [#{key_name}] is missing. Cannot SSH to the agent:#{instance.id}") if auth_key.nil?

    ssh = LinuxAdmin::SSH.new(ip, agent_ami_login_user, auth_key)

    # prepare work directory
    ssh.perform_commands(["sudo mkdir -p #{WORK_DIR}"])
    ssh.perform_commands(["sudo chmod go+w #{WORK_DIR}"])

    # scp the default setting yaml file
    config = Tempfile.new('config.yml')
    begin
      config.write(create_config_yaml)
      config.close
      out = scp_file(ip, agent_ami_login_user, auth_key, config.path, "#{WORK_DIR}/config.yml")
    ensure
      config.unlink
    end

    # docker register
    if docker_login_required?
      raise "Need credentials to login" unless docker_auth

      docker_username = docker_auth.userid
      docker_password = docker_auth.password
      command_line = "sudo docker login"
      command_line << " #{docker_registry}"
      command_line << " -u #{docker_username} -p #{docker_password}"
      ssh.perform_commands([command_line])
    end

    # run docker image
    image = docker_login_required? ? "#{docker_registry}/#{docker_image}" : docker_image
    command_line = "sudo docker run -d --restart=always -v /dev:/host_dev -v #{WORK_DIR}/config.yml:#{WORK_DIR}/config.yml --privileged #{image}"
    ssh.perform_commands([command_line])
  end

  def docker_auth
    @ems.authentications.find_by(:authtype => "smartstate_docker")
  end

  # Get Key Pair for SSH. Create a new one if not exists.
  def find_or_create_keypair(keypair_name = default_keypair_name)
    get_keypair(keypair_name) || begin
      _log.info("KeyPair #{keypair_name} will be created!")
      # Delete from Aws if existing
      ec2.key_pair(keypair_name).try(:delete)
      ManageIQ::Providers::CloudManager::AuthKeyPair.create_key_pair(@ems.id, :key_name => keypair_name)
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
    sgs = ec2.client.describe_security_groups(
      :filters => [{
        :name   => "group-name",
        :values => [group_name]
      }]
    ).security_groups
    return sgs[0].group_id unless sgs.empty?

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

  def get_subnets(az)
    ec2.client.describe_subnets(
      :filters => [{
        :name   => "availability-zone",
        :values => [az]
      }]
    ).subnets
  end

  # possible RHEL image name: values: [ "RHEL-7.3_HVM_GA*" ]
  def get_agent_image_id(image_name = agent_ami_name)
    imgs = ec2.client.describe_images(
      :filters => [{
        :name   => "name",
        :values => [image_name]
      }]
    ).images

    _log.info("AMI Image: #{image_name} [#{imgs[0].image_id}] is used to launch smartstate agent.")

    imgs[0].image_id
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
  rescue => err
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
