class ManageIQ::Providers::Amazon::AgentCoordinatorWorker::Runner < MiqWorker::Runner
  include ResponseThread
  def do_before_work_loop
    @coordinators = self.class.all_agent_coordinators_in_zone
    @coordinators.each(&:cleanup_agents)

    @coordinators_mutex = Mutex.new
    start_response_thread
  end

  def do_work
    @coordinators.each do |m|
      alive_agents = m.alive_agent_ids

      _log.info("Alive agents in EMS(guid=#{m.ems.guid}): #{alive_agents}.")

      # Only setup agents when:
      # 1. there is no running agents;
      # 2. get new requests;
      # 3. coordinator is not in deploying agent state;
      m.startup_agent if alive_agents.empty? && !m.request_queue_empty? && !m.deploying?

      # Turn flag off if deploying is done.
      m.deploying = false unless alive_agents.empty?
    end

    # Amazon providers may be added/removed. Keep monitor and update if needed.
    latest_ems_guids = self.class.amazon_ems_guids
    @coordinators_mutex.synchronize do
      coordinator_guids = @coordinators.collect { |m| m.ems.guid }
      self.class.refresh_coordinators(@coordinators, coordinator_guids, latest_ems_guids)
    end
  end

  def before_exit(_message, _exit_code)
    _log.info("Do cleanup before worker exits.")
    @coordinators.each(&:cleanup_agents)
  end

  def self.agent_coordinator_by_guid(guid)
    all_agent_coordinators_in_zone.find { |e| e.ems.guid == guid }
  end

  def self.ems_by_guid(guid)
    all_valid_ems_in_zone.detect { |e| e.guid == guid }
  end

  def self.amazon_ems_guids
    all_amazon_ems_in_zone.collect(&:guid)
  end

  def self.all_ems_in_zone
    MiqServer.my_server.zone.ext_management_systems
  end

  def self.all_valid_ems_in_zone
    all_ems_in_zone.select { |e| e.enabled && e.authentication_status_ok? }
  end

  def self.all_amazon_ems_in_zone
    all_valid_ems_in_zone.select { |e| e.kind_of?(ManageIQ::Providers::Amazon::CloudManager) }
  end

  def self.all_agent_coordinators_in_zone
    all_amazon_ems_in_zone.collect { |e| ManageIQ::Providers::Amazon::AgentCoordinator.new(e) }
  end

  def self.refresh_coordinators(coordinators, old_guids, new_guids)
    to_delete = old_guids - new_guids
    coordinators.delete_if { |m| to_delete.include?(m.ems.guid) } if to_delete.any?

    to_create = new_guids - old_guids
    to_create.each { |guid| coordinators << ManageIQ::Providers::Amazon::AgentCoordinator.new(ems_by_guid(guid)) }
  end
end
