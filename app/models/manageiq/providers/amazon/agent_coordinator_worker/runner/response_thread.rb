module ManageIQ::Providers::Amazon::AgentCoordinatorWorker::Runner::ResponseThread
  include ScanningMixin
  require 'util/xml/xml_utils'

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
        response_handler_loop
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

  def response_handler_loop
    @shutdown_instance_wait_thread = nil
    @response_data_dir = response_data_dir
    until @shutdown_instance_wait_thread
      @coordinators_mutex.synchronize do
        @coordinators.each do |coord|
          _log.debug("Checking replies for Agent Coordinator Provider #{coord.ems.name}")
          break if @shutdown_instance_wait_thread
          if coord.reply_queue_empty?
            _log.debug("No Replies visible for Provider #{coord.ems.name}")
          else
            ssaq = coord.ssa_queue
            _log.debug("Getting replies for #{coord.ems.name}")
            ssaq.reply_loop do |reply|
              begin
                _log.debug("Reply for #{coord.ems.name}: #{reply}")
                perform_metadata_sync(reply)
              rescue => err
                _log.error("Error #{err} processing replies for #{coord.ems.name}.  Continuing.")
                next
              end
            end
          end
        end
      end # end of synchronized block
      _log.debug("going to sleep for #{response_thread_sleep_seconds} seconds after checking all Agent Coordinators")
      sleep(response_thread_sleep_seconds) unless @shutdown_instance_wait_thread
    end
  end

  def perform_metadata_sync(extract_reply)
    ost       = OpenStruct.new
    ost.reply = extract_reply
    ost.jobid = extract_reply[:job_id]
    job       = Job.find_by(:id => ost.jobid)
    raise _("Unable to sync data for job with id %{job_id}") % {:job_id =>ost.jobid} if job.nil?
    target_id  = job.target_id
    vm         = VmOrTemplate.find(target_id)
    ost.taskid = job.guid
    unless vm.kind_of?(ManageIQ::Providers::Amazon::CloudManager::Vm) ||
           vm.kind_of?(ManageIQ::Providers::Amazon::CloudManager::Template)
      error = "Vm #{vm.name} of class #{vm.class.name} is not an Amazon instance or image - unable to sync data"
      update_job_message(ost, error)
      job.signal(:abort, error, "error")
      return
    end
    _log.debug("Syncing Metadata for #{vm.ems_ref}")
    if extract_reply[:error]
      update_job_message(ost, extract_reply[:error])
      job.signal(:abort, extract_reply[:error], "error")
      return
    end
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

    ost.skipConfig = true
    ost.config     = OpenStruct.new(
      :dataDir            => @response_data_dir,
      :forceFleeceDefault => false
    )

    begin
      require 'blackbox/VmBlackBox'
      _log.debug("instantiating BlackBox")
      bb = Manageiq::BlackBox.new(vm.guid, ost)
      _log.debug("instantiated BlackBox")
      categories = ost.reply[:categories].keys
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
        xml = MIQRexml.load(ost.reply[:categories][c])
        if xml.nil?
          _log.warn("No XML loaded for [#{c}].")
          next
        elsif xml.root.nil?
          _log.warn("No XML root loaded for [#{c}]: XML is #{xml}.")
          next
        end
        _log.debug("Writing scanned data to XML for [#{c}] to blackbox.")
        bb.saveXmlData(xml, c.to_s)
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
      bb&.close
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

  def response_data_dir
    response_data_dir = Rails.root.join("data", "metadata").expand_path
    unless File.exist?(response_data_dir)
      _log.debug("creating #{response_data_dir}")
      FileUtils.mkdir_p(response_data_dir)
    end
    response_data_dir
  end

  def response_thread_sleep_seconds
    Settings.ems.ems_amazon.agent_coordinator.response_thread_sleep_seconds
  end
end
