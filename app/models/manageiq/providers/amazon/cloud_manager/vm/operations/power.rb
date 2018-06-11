module ManageIQ::Providers::Amazon::CloudManager::Vm::Operations::Power
  extend ActiveSupport::Concern
  included do
    supports_not :suspend
  end

  def validate_pause
    validate_unsupported("Pause Operation")
  end

  def raw_start
    Ansible::Runner.run(ext_management_system.ansible_env_vars,
                        {:instance_ids => ems_ref},
                        ext_management_system.ansible_root.join("start_vm.yml"))

    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "powering_up")
  end

  def raw_stop
    Ansible::Runner.run(ext_management_system.ansible_env_vars,
                        {:instance_ids => ems_ref},
                        ext_management_system.ansible_root.join("stop_vm.yml"))

    # Temporarily update state for quick UI response until refresh comes along
    self.update_attributes!(:raw_power_state => "shutting_down")
  end
end
