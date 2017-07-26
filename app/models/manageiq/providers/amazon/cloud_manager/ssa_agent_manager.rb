require 'aws-sdk'
require 'linux_admin'
require 'amazon_ssa_support'

module ManageIQ::Providers::Amazon::CloudManager::SsaAgentManager

  MIQ_SSA = "MIQ_SSA"

  #
  # Intialize Amazon services
  #

  def ec2
    @ec2 ||= ext_management_system.connect(:service => 'EC2')
  end

  def sqs
    @sqs ||= ext_management_system.connect(:service => 'SQS')
  end

  def s3
    @s3 ||= ext_management_system.connect(:service => 'S3')
  end

  def iam
    @iam ||= ext_management_system.connect(:service => 'IAM')
  end

  def config
    @config ||= VMDB::Config.new("vmdb").config
  end

  def region
    ext_management_system.provider_region
  end

  def log_level
    ll = config[:log][:level_aws] || AmazonSsaSupport::DEFAULT_LOG_LEVEL
    ll.upcase
  end

  def heartbeat_prefix
    config[:aws_ssa_heartbeat_prefix] || AmazonSsaSupport::DEFAULT_HEARTBEAT_PREFIX
  end

  def heartbeat_interval
    config[:aws_ssa_heartbeat_interval] || AmazonSsaSupport::DEFAULT_HEARTBEAT_INTERVAL
  end

  def ssa_bucket
    (config[:aws_ssa_bucket] || AmazonSsaSupport::DEFAULT_BUCKET_PREFIX) + '-' + ext_management_system.guid
  end

  def request_queue
    config[:aws_ssa_request_queue] || AmazonSsaSupport::DEFAULT_REQUEST_QUEUE
  end

  def reply_queue
    config[:aws_ssa_reply_queue] || AmazonSsaSupport::DEFAULT_REPLY_QUEUE
  end

  def reply_prefix
    config[:aws_ssa_reply_prefix] || AmazonSsaSupport::DEFAULT_REPLY_PREFIX
  end

  def log_prefix
    config[:aws_ssa_log_prefix] || AmazonSsaSupport::DEFAULT_LOG_PREFIX
  end

  def profile_name
    MIQ_SSA
  end

  # check timestamp of heartbeat of agent_id, return true if the last beat time in
  # in the time interval
  def agent_alive?(agent_id, interval = 300)
    bucket = s3.bucket(ssa_bucket)
    return false unless bucket.exists?

    obj_id = heartbeat_prefix + agent_id
    obj = bucket.object(obj_id)
    return false unless obj.exists?
   
    last_beat_stamp = YAML.load(obj.get.body.read, safe: true)
    Time.now.utc - last_beat_stamp > interval ? false : true
  end

  def deploy_agent
    kp = get_key_pair
    security_group_id = create_security_group
    data = create_user_data
    zone_name = ec2.client.describe_availability_zones.availability_zones[0].zone_name
    subnets = get_subnets(zone_name)
    raise "No subnet_id is available for #{zone_name}!" if subnets.length == 0
    create_profile

    instance = ec2.create_instances({
      image_id: get_agent_image_id,
      min_count: 1,
      max_count: 1,
      key_name: kp.name,
      security_group_ids: [security_group_id],
      user_data: data,
      instance_type: 't2.micro',
      placement: {
        availability_zone: zone_name
      },
      subnet_id: subnets[0].subnet_id,
      iam_instance_profile: {
        name: profile_name
      },
      tag_specifications: [{
        resource_type: "instance",
        tags: [{
          key: "Name",
          value: MIQ_SSA
        }]
      }]
    })
    ec2.client.wait_until(:instance_status_ok, {instance_ids: [instance[0].id]})

    instance[0].id
  end

  private
  def role_exists?(role_name)
    begin
      role = iam.role(role_name)
      role.role_id
      true
    rescue ::Aws::IAM::Errors::NoSuchEntity
      false
    end
  end

  def create_role(role_name = MIQ_SSA)
    return if role_exists?(role_name)

    # Policy Generator:
    policy_doc = {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {"Service": "ec2.amazonaws.com"},
          "Action": "sts:AssumeRole"
        }
      ]
    }

    role = iam.create_role({
      role_name: role_name,
      assume_role_policy_document: policy_doc.to_json
    })
    
    # grant all priviledges
    role.attach_policy({
      policy_arn: 'arn:aws:iam::aws:policy/AmazonS3FullAccess'
    })
    
    role.attach_policy({
      policy_arn: 'arn:aws:iam::aws:policy/AmazonEC2FullAccess'
    })
    
    role.attach_policy({
      policy_arn: 'arn:aws:iam::aws:policy/AmazonSQSFullAccess'
    })

    role
  end

  def create_profile(profile_name = MIQ_SSA, role_name = MIQ_SSA)
    ssa_profile = iam.instance_profile(profile_name)
    ssa_profile = iam.create_instance_profile(instance_profile_name: profile_name) unless ssa_profile.exists?

    create_role(role_name) unless role_exists?(role_name)
    ssa_profile.add_role(role_name: role_name) if ssa_profile.roles.size == 0

    ssa_profile
  end

  def get_agent_image_id
    imgs = ec2.client.describe_images(
      filters: [
        {
          name: "name",
          values: [ "RHEL-7.3_HVM_GA*" ]
        }
      ]
    ).images

    imgs[0].image_id
  end

  def create_security_group(group_name = MIQ_SSA)
    begin
      sgs = ec2.client.describe_security_groups(
        filters: [
          {
            name: "group-name",
            values: [ group_name ]
          }
        ]
      ).security_groups
      return sgs[0].group_id if sgs.length > 0

      # create security group if not exist
      security_group = ec2.create_security_group({
        group_name: group_name,
        description: 'Security group for MIQ SSA Agent',
        vpc_id: ec2.client.describe_vpcs.vpcs[0].vpc_id
      })

      sg_authorize_ingress(security_group, 'tcp', 22, 22)
      sg_authorize_ingress(security_group, 'tcp', 80, 80)
      sg_authorize_ingress(security_group, 'tcp', 443, 443)

      security_group.group_id
    end
  end

  def sg_authorize_ingress(sg, protocal, from_port, to_port)
      sg.authorize_ingress({
        ip_permissions: [{
          ip_protocol: protocol,
          from_port: from_port,
          to_port: to_port,
          ip_ranges: [{
            cidr_ip: '0.0.0.0/0'
          }]}]
      })
  end

  # Get Key Pair for SSH. Create a new one if not exists. 
  def get_key_pair(pair_name = MIQ_SSA)
    kp = Authentication.where(name: pair_name)
    return kp[0] if kp.length > 0

    ManageIQ::Providers::CloudManager::AuthKeyPair.create_key_pair(ext_management_system.id,
      { :key_name => pair_name })
  end

  def create_pem_file(pair_name = MIQ_SSA)
    kp = get_key_pair(pair_name)
    pem_file_name = pair_name + ".pem"
    File.open(pem_file_name, 'w') {|f| f.write(kp.auth_key) }
    File.chmod(0400, pem_file_name)
    pem_file_name
  end

  def setup_ruby(log = '/var/log/miq_ssa_deploy.log')
    <<~HEREDOC
      yum -y update > #{log} 2>&1
      yum -y install git-core zlib zlib-devel gcc-c++ patch readline readline-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison curl sqlite-devel postgresql-devel >> #{log} 2>&1
      git clone https://github.com/rbenv/rbenv.git ~/.rbenv >> #{log} 2>&1
      export HOME="/root" >> #{log} 2>&1
      echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
      echo 'eval "$(/root/.rbenv/bin/rbenv init -)"' >> ~/.bash_profile
      source ~/.bash_profile >> #{log} 2>&1
      git clone git://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build >> #{log} 2>&1
      echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bash_profile
      source ~/.bash_profile >> #{log} 2>&1
      echo $PATH >> #{log} 2>&1
      rbenv install -l >> #{log} 2>&1
      rbenv install 2.3.3 >> #{log} 2>&1
      rbenv global 2.3.3 >> #{log} 2>&1
      gem install bundler >> #{log} 2>&1
      gem install rails >> #{log} 2>&1
      gem install aws-sdk >> #{log} 2>&1
      rbenv rehash >> #{log} 2>&1
      ruby -v >> #{log} 2>&1
    HEREDOC
  end

  def default_settings
    <<~HEREDOC
      echo "---" > default_ssa_config.yml
      echo ":log_level: #{log_level}" >> default_ssa_config.yml
      echo ":region: #{region}" >> default_ssa_config.yml
      echo ":request_queue: #{request_queue}" >> default_ssa_config.yml
      echo ":reply_queue: #{reply_queue}" >> default_ssa_config.yml
      echo ":ssa_bucket: #{ssa_bucket}" >> default_ssa_config.yml
      echo ":reply_prefix: #{reply_prefix}" >> default_ssa_config.yml
      echo ":log_prefix: #{log_prefix}" >> default_ssa_config.yml
      echo ":heartbeat_prefix: #{heartbeat_prefix}" >> default_ssa_config.yml
      echo ":heartbeat_interval: #{heartbeat_interval}" >> default_ssa_config.yml
    HEREDOC
  end

  def github_gem_file
    <<~HEREDOC
      echo 'source "https://rubygems.org"' > Gemfile
      echo 'gem "manageiq-gems-pending", ">0", :require => "manageiq-gems-pending", :git => "https://github.com/ManageIQ/manageiq-gems-pending.git", :branch => "master"' >> Gemfile
      echo 'gem "manageiq-smartstate", ">0", :require => "manageiq-smartstate", :git => "https://github.com/ManageIQ/manageiq-smartstate.git", :branch => "master"' >> Gemfile
      echo 'gem "amazon_ssa_support", ">0", :require => "amazon_ssa_support", :git => "https://github.com/ManageIQ/amazon_ssa_support.git", :branch => "master"' >> Gemfile
      # Modified gems for gems-pending.  Setting sources here since they are git references
      echo 'gem "handsoap", "~>0.2.5", :require => false, :git => "https://github.com/ManageIQ/handsoap.git", :tag => "v0.2.5-5"' >> Gemfile
      echo 'gem "aws-sdk"' >> Gemfile
    HEREDOC
  end

  def agent_startup_script(log = '/var/log/miq_ssa_deploy.log')
    <<~HEREDOC
      echo "#!/bin/sh" > start_agent.sh
      echo "ssa_root=`bundle show amazon_ssa_support`" >> start_agent.sh
      echo 'ssa_script="$ssa_root/tools/amazon_ssa_extract.rb"' >> start_agent.sh
      echo 'ruby $ssa_script -l #{log_level}' >> start_agent.sh
      chmod 755 start_agent.sh
      echo "Agent starts ..." >> #{log} 2>&1
      ./start_agent.sh
    HEREDOC
  end

  def create_user_data(log = '/var/log/miq_ssa_deploy.log')
    userdata = <<~HEREDOC
      #!/bin/bash
      #{setup_ruby}
      mkdir -p /opt/miq/log
      cd /opt/miq
      #{github_gem_file}
      bundle install >> #{log} 2>&1
      #{default_settings} 
      #{agent_startup_script}
    HEREDOC
    Base64.encode64(userdata)
  end

  def get_subnets(az)
    ec2.client.describe_subnets(filters: [
      {
        name: "availability-zone",
        values: [ az ]
      }
    ]).subnets
  end
end
