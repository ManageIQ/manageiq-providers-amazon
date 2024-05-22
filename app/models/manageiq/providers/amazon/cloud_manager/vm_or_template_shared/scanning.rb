module ManageIQ::Providers::Amazon::CloudManager::VmOrTemplateShared::Scanning
  extend ActiveSupport::Concern
  require 'xml/xml_utils'
  require 'scanning_operations_mixin'

  included do
    supports(:smartstate_analysis) { unsupported_reason(:action) }
  end

  def scan_job_class
    ManageIQ::Providers::Amazon::CloudManager::Scanning::Job
  end

  def require_snapshot_for_scan?
    false
  end

  def scan_via_ems?
    true
  end

  def perform_metadata_scan(ost)
    require 'amazon_ssa_support'
    connect_args           = {}
    connect_args[:service] = :SQS
    @sqs = ext_management_system.connect(connect_args)
    raise "Unable to obtain a new SQS resource" unless @sqs
    connect_args[:service] = :S3
    @s3                    = ext_management_system.connect(connect_args)
    raise "Unable to obtain a new S3 resource" unless @s3
    ssaq_args              = {}
    ssaq_args[:ssa_bucket]    = "#{AmazonSsaSupport::DEFAULT_BUCKET_PREFIX}-#{ext_management_system.guid}"
    ssaq_args[:request_queue] = "#{AmazonSsaSupport::DEFAULT_REQUEST_QUEUE}-#{ext_management_system.guid}"
    ssaq_args[:reply_queue]   = "#{AmazonSsaSupport::DEFAULT_REPLY_QUEUE}-#{ext_management_system.guid}"
    ssaq_args[:region]        = ext_management_system.provider_region
    ssaq_args[:sqs]           = @sqs
    ssaq_args[:s3]            = @s3

    begin
      ssaq = AmazonSsaSupport::SsaQueue.new(ssaq_args)
      raise "Error creating SsaQueue for #{ems_ref}" unless ssaq
      ost.ssaq = ssaq
      _log.debug("sending extract request for #{ems_ref}")
      categories     = ost.category&.split(',') || AmazonSsaSupport::SsaQueueExtractor::CATEGORIES
      request        = ssaq.send_extract_request(ems_ref, ost.jobid, categories, ost)
      ost.message_id = request.message_id
      _log.debug("Extract request ID #{request.message_id} submitted")
    rescue => err
      raise "Unable to send extract request: #{err}"
    end
    msg = "Scanning in AWS region #{ssaq_args[:region]} in progress"
    update_job_message(ost, msg)
    job = Job.find_by(:id => ost.jobid)
    raise _("Unable to process data for job with id %{job_id}") % {:job_id => ost.jobid} if job.nil?
    job.process_finished(msg, "ok")
  end

  def perform_metadata_sync(ost)
    require 'amazon_ssa_support'
    sync_stashed_metadata(ost)
  end

  def proxies4job(_job = nil)
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
