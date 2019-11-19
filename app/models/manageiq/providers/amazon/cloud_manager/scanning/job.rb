class ManageIQ::Providers::Amazon::CloudManager::Scanning::Job < VmScan
  # Make updates to default state machine for scanning on AWS
  #
  ######################################################################################################################################################
  #
  # AWS SmartState flow:
  #
  #   - vm.scan_metadata is called from VmScan#call_scan method
  #     * vm.scan_metadata method lives in ScanningMixin
  #   - vm.scan_metadata calls MiqServer::ServerSmartProxy#queue_call
  #   - MiqServer::ServerSmartProxy#queue_call passes control (via MiqQueue) to MiqServer::ServerSmartProxy#scan_metadata
  #   - MiqServer::ServerSmartProxy#scan_metadata calls ManageIQ::Providers::Amazon::CloudManager::VmOrTemplateShared::Scanning#perform_metadata_scan
  #   - The perform_metadata_scan method queues the request via Amazon's SQS
  #     * Then the job is marked as finished - and THAT is why the transition below is needed
  #
  #   - In a different worker process, ManageIQ::Providers::Amazon::AgentCoordinatorWorker::Runner
  #     * checks if a ManageIQ agent is running in the Amazon AWS Cloud, and starts it, if needed
  #
  #   - The ManageIQ agent in Amazon AWS Cloud
  #     * starts up
  #     * reads the requests in the SQS queue
  #     * For each request,
  #       * does the scanning
  #       * saves the result in an S3 bucket
  #       * puts response into SQS queue
  #
  #   - In a different worker process, ManageIQ::Providers::Amazon::AgentCoordinatorWorker::Runner starts a ResponseThread
  #     * The ResponseThread checks the SQS queue intermittently.
  #     * When it gets a response, it could be multiple responses from multiple scan requests
  #     *   so, for each reply to a scan request, it calls ManageIQ::Providers::Amazon::AgentCoordinatorWorker::Runner::ResponseThread#perform_metadata_sync
  #     * The perform_metadata_sync method
  #     *   will figure out what Job the reply is for
  #     *   will figure out what Vm  the reply is for
  #     *   update the job's status
  #     *   sync scanning results into XML
  #     *   calls vm.save_metadata_op(MIQEncode.encode(xml_summary.to_xml.to_s), "b64,zlib,xml", job.guid)
  #
  ######################################################################################################################################################
  def load_transitions
    super.tap do |transactions|
      transactions.merge!(
        :finish => {'scanning' => 'finished'}
      )
    end
  end
end
