module ManageIQ::Providers::Amazon::CloudManager::VmOrTemplateShared::Scanning
  extend ActiveSupport::Concern
  require 'amazon_ssa_support'

  included do
    supports :smartstate_analysis do
      feature_supported, reason = check_feature_support('smartstate_analysis')
      unless feature_supported
        unsupported_reason_add(:smartstate_analysis, reason)
      end
    end
  end

  def scan_via_ems?
    true
  end

  def perform_metadata_scan(ost)
    connect_args           = {}
    connect_args[:service] = :SQS
    @sqs = ext_management_system.connect(connect_args)
    raise "Unable to obtain a new SQS resource" unless @sqs
    connect_args[:service] = :S3
    @s3                    = ext_management_system.connect(connect_args)
    raise "Unable to obtain a new S3 resource" unless @s3
    ssaq_args                 = {}
    ssaq_args[:ssa_bucket]    = name
    ssaq_args[:region]        = ext_management_system.provider_region
    ssaq_args[:sqs]           = @sqs
    ssaq_args[:s3]            = @s3

    begin
      ssaq = AmazonSsaSupport::SsaQueue.new(ssaq_args)
      raise "Error creating SsaQueue for #{ems_ref}" unless ssaq
      ssaq.send_extract_request(ems_ref, ost.jobid, AmazonSsaSupport::SsaQueueExtractor::CATEGORIES)
    rescue => err
      raise "Unable to send extract request #{err}"
    end
  end

  def perform_metadata_sync(ost)
    sync_stashed_metadata(ost)
  end

  def proxies4job(job)
    {
      :proxies => [MiqServer.my_server],
      :message => 'Perform SmartState Analysis on this Instance'
    }
  end

  def has_active_proxy?
    true
  end

  def has_proxy?
    true
  end

  def requires_storage_for_scan?
    false
  end
end
