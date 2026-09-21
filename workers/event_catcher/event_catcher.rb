# Load KubernetesEventCatcherBase from the manageiq-providers-kubernetes gem.
# In production the gem is installed via the inline gemfile in the worker binary.
# In development/test the local checkout is used via the path gem in Gemfile.
k8s_base = if (spec = Gem.loaded_specs['manageiq-providers-kubernetes'])
             File.join(spec.gem_dir, 'lib/manageiq/providers/kubernetes/workers/event_catcher_base')
           else
             File.expand_path('../../../manageiq-providers-kubernetes/lib/manageiq/providers/kubernetes/workers/event_catcher_base', __dir__)
           end
require k8s_base

require 'kubeclient/aws_eks_credentials'
require 'aws-sdk-sts'

class EventCatcher < KubernetesEventCatcherBase
  TOKEN_TTL = 60

  attr_reader :token_expiry

  private

  def auth_options
    credentials   = Aws::Credentials.new(authentication['userid'], authentication['password'])
    token         = Kubeclient::AmazonEksCredentials.token(credentials, ems['uid_ems'])
    @token_expiry = Time.now.utc + TOKEN_TTL
    {:bearer_token => token}
  end

  def log_prefix
    'MIQ(ManageIQ::Providers::Amazon::ContainerManager::EventCatcher)'
  end
end
