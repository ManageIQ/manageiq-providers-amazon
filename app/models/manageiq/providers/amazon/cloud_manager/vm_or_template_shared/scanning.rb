module ManageIQ::Providers::Amazon::CloudManager::VmOrTemplateShared::Scanning
  extend ActiveSupport::Concern
  require 'amazon_ssa_support'
  require 'xml/xml_utils'
  require 'scanning_operations_mixin'

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
    ssaq_args              = {}
    ssaq_args[:ssa_bucket] = ext_management_system.guid
    ssaq_args[:region]     = ext_management_system.provider_region
    ssaq_args[:sqs]        = @sqs
    ssaq_args[:s3]         = @s3

    begin
      ssaq = AmazonSsaSupport::SsaQueue.new(ssaq_args)
      raise "Error creating SsaQueue for #{ems_ref}" unless ssaq
      ost.ssaq = ssaq
      _log.debug("sending extract request for #{ems_ref}")
      ost.category   = AmazonSsaSupport::SsaQueueExtractor::CATEGORIES
      request        = ssaq.send_extract_request(ems_ref, ost.jobid, ost.category)
      ost.message_id = request.message_id
      #
      # TODO:  This request should be handed off to a worker responsible FOR watching for job completion
      # In addition the instance manager should get kicked in the shin so it can determine if there
      # are instances available to handle this request and act accordingly if not.
      # For now, we will simply call perform_instance_wait, which will wait for the *NEXT* job
      # to be completed and handle it as if it is the one we care about (a possibly faulty assumption)
      #
    rescue => err
      raise "Unable to send extract request: #{err}"
    end
    perform_instance_wait(ost)
  end

  def perform_instance_wait(ost)
    _log.debug("Waiting for Amazon Instance for #{ems_ref}")
    ssaq          = ost.ssaq
    extract_reply = nil
    until extract_reply
      sleep(60)
      begin
        ssaq.reply_loop do |reply|
          _log.debug("Reply for #{ems_ref}: #{reply}")
          extract_reply = reply
        end
      rescue => err
        raise "Unable to get reply to scan request from instance: #{err}"
      end
    end
    raise "No reply received for scan request from instance #{ems_ref}" unless extract_reply
    ost.reply = extract_reply
    perform_metadata_sync(ost)
  end

  def perform_metadata_sync(ost)
    _log.debug("Syncing Metadata for #{ems_ref}")
    update_job_message(ost, "Synchronization in progress")
    status        = scan_message         = "OK"
    status_code   = categories_processed = 0
    ost.xml_class = XmlHash::Document
    bb            = last_err             = nil

    xml_summary = ost.xml_class.createDoc(:summary)
    xml_node    = xml_node_scan = xml_summary.root.add_element("scanmetadata")
    xml_summary.root.add_attributes("taskid" => ost.taskid)

    data_dir = File.expand_path(Rails.root.join("data/metadata"))
    _log.debug "creating #{data_dir}"
    begin
      Dir.mkdir(data_dir)
    rescue Errno::EEXIST
      # Ignore if the directory was created by another thread
      _log.debug "No need to create directory #{data_dir} since it exists."
    end unless File.exist?(data_dir)
    ost.skipConfig = true
    ost.config     = OpenStruct.new(
      :dataDir            => data_dir,
      :forceFleeceDefault => false
    )

    begin
      require 'blackbox/VmBlackBox'
      _log.debug "instantiating BlackBox"
      bb = Manageiq::BlackBox.new(guid, ost)
      _log.debug "instantiated BlackBox"
      categories = ost.category
      #
      # TODO: The amazon_ssa_support gem defines the category as an array,
      # But the scanning_mixin expects it to be a comma-separated string.
      # We should fix the gem....
      #
      ost.category = categories.join(",")

      categories.each do |c|
        update_job_message(ost, "Syncing #{c}")
        st = Time.current
        xml = MIQRexml.load(ost.reply[:categories][c.to_sym])
        next unless xml
        _log.debug "Writing scanned data to XML for [#{c}] to blackbox."
        bb.saveXmlData(xml, c)
        _log.debug "Writing XML complete."

        category_node = xml_summary.class.load(xml.root.shallow_copy.to_xml.to_s).root
        category_node.add_attributes("start_time" => st.utc.iso8601, "end_time" => Time.now.utc.iso8601)
        xml_node << category_node
        categories_processed += 1
      end
    rescue NoMethodError => scan_err
      last_err = scan_err
      _log.error "perform_metadata_sync Error - [#{scan_err}]"
      _log.error "perform_metadata_sync Error - [#{scan_err.backtrace.join("\n")}]"
    ensure
      bb.close if bb
      update_job_message(ost, "Scanning completed.")
      if last_err
        status = "Error"
        status_code = 8
	status_code = 16 if categories_processed.zero?
        scan_message = last_err.to_s
        _log.error "ScanMetadata error status:[#{status_code}]:  message:[#{last_err}]"
        _log.debug { last_err.backtrace.join("\n") }
      end

      xml_node_scan.add_attributes(
        "end_time"    => Time.now.utc.iso8601,
        "status"      => status,
        "status_code" => status_code.to_s,
        "message"     => scan_message
      )
      save_metadata_op(MIQEncode.encode(xml_summary.to_xml.to_s), "b64,zlib,xml", ost.taskid)
      _log.info "Completed: Sending scan summary to server.  TaskId:[#{ost.taskid}]  target:[#{name}]"
    end
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
