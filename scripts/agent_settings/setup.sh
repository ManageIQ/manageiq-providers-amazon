#!/bin/bash



function setup_ruby() {
yum -y update
yum -y install git-core zlib zlib-devel gcc-c++ patch readline readline-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison curl sqlite-devel postgresql-devel
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
export HOME="/root"
echo 'export HOME="/root"' >> ~/.bash_profile
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bash_profile
echo "eval '$(/root/.rbenv/bin/rbenv init -)'" >> ~/.bash_profile
source ~/.bash_profile
git clone git://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
echo $PATH
rbenv install -l
rbenv install ${AGENT_RUBY_VERSION}
rbenv global ${AGENT_RUBY_VERSION}
gem install bundler
rbenv rehash
ruby -v
}
#
# Install Gems
#

function install_gems() {
echo 'source "https://rubygems.org"' >> Gemfile
echo 'gem "amazon_ssa_support", ">0", :require => "amazon_ssa_support", :git => "https://github.com/ManageIQ/amazon_ssa_support.git", :branch => "master"' >> Gemfile
echo 'gem "handsoap", "~>0.2.5", :require => false, :git => "https://github.com/ManageIQ/handsoap.git", :tag => "v0.2.5-5"' >> Gemfile
echo 'gem "manageiq-gems-pending", ">0", :require => "manageiq-gems-pending", :git => "https://github.com/ManageIQ/manageiq-gems-pending.git", :branch => "master"' >> Gemfile
echo 'gem "manageiq-smartstate", "0.2.1", :require => "manageiq-smartstate"' >> Gemfile
bundle install
}
#
# Create settings yaml file 
#
function create_setting_yml() {
echo '---' >> default_ssa_config.yml
echo ':bucket_prefix: miq-ssa' >> default_ssa_config.yml
echo ':request_queue_prefix: ssa_extract_request' >> default_ssa_config.yml
echo ':reply_queue_prefix: ssa_extract_reply' >> default_ssa_config.yml
echo ':reply_prefix: extract/queue-reply/' >> default_ssa_config.yml
echo ':heartbeat_prefix: extract/heartbeat/' >> default_ssa_config.yml
echo ':log_prefix: extract/logs/' >> default_ssa_config.yml
echo ':log_level: INFO' >> default_ssa_config.yml
echo ':heartbeat_interval: 120' >> default_ssa_config.yml
echo ':agent_idle_period: 900' >> default_ssa_config.yml
echo ':userdata_script_file: tools/amazon_agent_settings/prepare_userdata' >> default_ssa_config.yml
echo ':region: us-east-1' >> default_ssa_config.yml
echo ':request_queue: ssa_extract_request-7bb7a4ee-c41a-4a06-8a33-075664bba709' >> default_ssa_config.yml
echo ':reply_queue: ssa_extract_reply-7bb7a4ee-c41a-4a06-8a33-075664bba709' >> default_ssa_config.yml
echo ':ssa_bucket: miq-ssa-7bb7a4ee-c41a-4a06-8a33-075664bba709' >> default_ssa_config.yml
}
#
# Add following commands into rc.local, so they can be autorun after power on
#
function add_rc_local_script() {
chmod +x /etc/rc.d/rc.local
echo 'source /root/.bash_profile' >> /etc/rc.d/rc.local
echo "cd ${WORK_DIR} && bundle exec amazon_ssa_agent &" >> /etc/rc.d/rc.local
}

#
# Setup environment
#
cd $WORK_DIR
echo "Start to setup Amazon agent"
(
  setup_ruby
  install_gems
  create_setting_yml
  add_rc_local_script
  bundle exec amazon_ssa_agent -l ${AGENT_LOG_LEVEL}
)  >> /var/www/miq/ssa_deploy.log 2>&1
