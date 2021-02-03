class ManageIQ::Providers::Amazon::ContainerManager < ManageIQ::Providers::Kubernetes::ContainerManager
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
end
