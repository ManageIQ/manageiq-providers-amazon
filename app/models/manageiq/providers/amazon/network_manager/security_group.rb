class ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup < ::SecurityGroup
  supports :create

  def self.display_name(number = 1)
    n_('Security Group (Amazon)', 'Security Groups (Amazon)', number)
  end

  def self.raw_create_security_group(ext_management_system, options, user_id)
    ext_management_system.notify_task_start(_('My awesome task is starting.'), user_id)
    begin
      task = Ansible::Runner.run(ext_management_system.parent_manager.ansible_env_vars,
                          {
                            :vpc_id                      => options["vpc_id"],
                            :security_group_name         => options["security_group_name"],
                            :security_group_description  => options["security_group_description"],
                            :security_group_rules        => options["security_group_rules"],
                            :security_group_rules_egress => options["security_group_rules_egress"],
                          },
                          ext_management_system.parent_manager.ansible_root.join("create_security_group.yml"))
    rescue => e
      _log.error("security_group=[#{options[:name]}], error: #{e}")
      ext_management_system.notify_task_fail(_('My awesome task failed.'), user_id)
      raise MiqException::MiqSecurityGroupCreateError, e.message, e.backtrace
    else
      ext_management_system.notify_task_finish(_('My awesome task finished.'), user_id)
    end

    task
  end
end
