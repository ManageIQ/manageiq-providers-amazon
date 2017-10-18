module ManageIQ::Providers::Amazon::AgentCoordinatorWorker::Runner::ResponseThread
  require 'xml/xml_utils'
  require 'scanning_mixin'
  include ScanningMixin

  #
  # This thread startup method is called by the AgentCoordinatorWorker::Runner
  # at the end of the do_before_work_loop method.
  #
  def start_response_thread
    Thread.new do
      _log.info("Starting AWS SSA Response Thread")
      begin
        # Wait a bit for the Agent Coordinators to be started
        sleep(20)
        wait_for_responses
      rescue SystemExit
        _log.info("SystemExit received, exiting AWS SSA Response Thread")
        stop_response_thread
        Thread.exit
      rescue => err
        _log.error("start_response_thread: Error [#{err}]")
        _log.error("start_response_thread: Error - [#{err.backtrace.join("\n")}]")
      end
    end
  end

  def stop_response_thread
    @shutdown_instance_wait_thread = true
  end

  def wait_for_responses
    @shutdown_instance_wait_thread = nil
    until @shutdown_instance_wait_thread
      @coordinators.each do |coord|
        _log.debug("Checking replies for Agent Coordinator Provider #{coord.ems.name}")
        break if @shutdown_instance_wait_thread
        if coord.reply_queue_empty?
          _log.debug("No Replies visible for Provider #{coord.ems.name}")
        else
          ssaq_args = {}
          ssaq_args[:ssa_bucket]    = coord.ssa_bucket
          ssaq_args[:reply_queue]   = coord.reply_queue
          ssaq_args[:request_queue] = coord.request_queue
          ssaq_args[:region]        = coord.ems.provider_region
          ssaq_args[:sqs]           = coord.sqs
          ssaq_args[:s3]            = coord.s3
          ssaq                      = AmazonSsaSupport::SsaQueue.new(ssaq_args)
          unless ssaq
            _log.error("Error creating SsaQueue for #{coord.ems.name}")
            next
          end
          _log.debug("Getting replies for #{coord.ems.name}")
          begin
            ssaq.reply_loop do |reply|
              _log.debug("Reply for #{coord.ems.name}: #{reply}")
              perform_metadata_sync(reply)
            end
          rescue => err
            _log.error("Error #{err} processing replies for #{coord.ems.name}.  Continuing.")
            next
          end
        end
      end
      break if @shutdown_instance_wait_thread
      # While this is WIP we will hard code this to 10 seconds.
      # reponse_check_sleep_seconds = response_thread_sleep_seconds
      response_check_sleep_seconds = 10
      _log.debug("going to sleep for #{response_check_sleep_seconds} seconds after getting all Agent Coordinators")
      sleep(response_check_sleep_seconds) unless @shutdown_instance_wait_thread
    end
  end

  def perform_metadata_sync(extract_reply)
    ost       = OpenStruct.new
    ost.reply = extract_reply
    ost.jobid = extract_reply[:job_id]
    job       = Job.find_by(:id => ost.jobid)
    raise _("Unable to sync data for job with id <%{number}>. Job not found.") % {:number => ost.jobid} if job.nil?
    ost.taskid = ost.jobid
    target_id  = job.target_id
    vm         = VmOrTemplate.find(target_id)
    unless vm.kind_of?(ManageIQ::Providers::Amazon::CloudManager::Vm)
      raise "Vm #{vm.name} of class #{vm.class.name} is not an Amazon vm - unable to sync data"
    end
    _log.debug("Syncing Metadata for #{vm.ems_ref}")
    ost.taskid = job.guid
    update_job_message(ost, "Synchronization in progress")
    status        = scan_message         = "OK"
    status_code   = categories_processed = 0
    ost.xml_class = XmlHash::Document
    bb            = last_err = nil

    xml_summary = ost.xml_class.createDoc(:summary)
    xml_node    = xml_node_scan = xml_summary.root.add_element("scanmetadata")
    xml_node_scan.add_attributes("start_time" => extract_reply[:start_time])
    xml_summary.root.add_attributes("taskid" => ost.taskid)
    ost.taskid = ost.jobid

    data_dir = File.expand_path(Rails.root.join("data/metadata"))
    _log.debug("creating #{data_dir}")
    begin
      Dir.mkdir(data_dir)
    rescue Errno::EEXIST
      # Ignore if the directory was created by another thread
      _log.debug("No need to create directory #{data_dir} since it exists.")
    end unless File.exist?(data_dir)
    ost.skipConfig = true
    ost.config     = OpenStruct.new(
      :dataDir            => data_dir,
      :forceFleeceDefault => false
    )

    begin
      require 'blackbox/VmBlackBox'
      _log.debug("instantiating BlackBox")
      bb = Manageiq::BlackBox.new(vm.guid, ost)
      _log.debug("instantiated BlackBox")
      categories = AmazonSsaSupport::SsaQueueExtractor::CATEGORIES
      #
      # The amazon_ssa_support gem defines the categories as an array,
      # But the scanning_mixin expects it to be a comma-separated string.
      #
      ost.category = categories.join(",")

      categories.each do |c|
        ost.taskid = job.guid
        update_job_message(ost, "Syncing #{c}")
        ost.taskid = ost.jobid
        st = Time.current
        xml = MIQRexml.load(ost.reply[:categories][c.to_sym])
        if xml.nil?
          _log.debug("No XML loaded for [#{c}].")
          next
        elsif xml.root.nil?
          _log.debug("No XML root loaded for [#{c}]: XML is #{xml}.")
          next
        end
        _log.debug("Writing scanned data to XML for [#{c}] to blackbox.")
        bb.saveXmlData(xml, c)
        _log.debug("Writing XML complete.")

        category_node = xml_summary.class.load(xml.root.shallow_copy.to_xml.to_s).root
        category_node.add_attributes("start_time" => st.utc.iso8601, "end_time" => Time.now.utc.iso8601)
        xml_node << category_node
        categories_processed += 1
      end
    rescue NoMethodError => scan_err
      last_err = scan_err
      _log.error("perform_metadata_sync Error - [#{scan_err}]")
      _log.error("perform_metadata_sync Error - [#{scan_err.backtrace.join("\n")}]")
    ensure
      bb.close if bb
      ost.taskid = job.guid
      update_job_message(ost, "Scanning completed.")
      ost.taskid = ost.jobid
      if last_err
        status = "Error"
        status_code  = 8
        status_code  = 16 if categories_processed.zero?
        scan_message = last_err.to_s
        _log.error("ScanMetadata error status:[#{status_code}]:  message:[#{last_err}]")
        _log.debug { last_err.backtrace.join("\n") }
      end

      xml_node_scan.add_attributes(
        "end_time"    => Time.now.utc.iso8601,
        "status"      => status,
        "status_code" => status_code.to_s,
        "message"     => scan_message
      )
      vm.save_metadata_op(MIQEncode.encode(xml_summary.to_xml.to_s), "b64,zlib,xml", job.guid)
      _log.info("Completed: Sending scan summary to server.  TaskId:[#{ost.taskid}]  target:[#{vm.name}]")
    end
  end

  def response_thread_sleep_seconds
    @response_thread_sleep_seconds ||= Settings.ems.ems_amazon.agent_coordinator.response_thread_sleep_seconds
  end
end
