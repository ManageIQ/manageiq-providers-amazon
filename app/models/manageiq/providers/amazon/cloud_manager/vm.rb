class ManageIQ::Providers::Amazon::CloudManager::Vm < ManageIQ::Providers::CloudManager::Vm
  include_concern 'Operations'
  include_concern 'ManageIQ::Providers::Amazon::CloudManager::VmOrTemplateShared'

  POWER_STATES = {
    "running"       => "on",
    "powering_up"   => "powering_up",
    "shutting_down" => "powering_down",
    "shutting-down" => "powering_down",
    "stopping"      => "powering_down",
    "pending"       => "suspended",
    "terminated"    => "terminated",
    "stopped"       => "off",
    "off"           => "off",
    # 'unknown' will be set by #disconnect_ems - which means 'terminated' in our case
    "unknown"       => "terminated",
  }.freeze

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.instance(ems_ref)
  end

  #
  # Relationship methods
  #

  def disconnect_inv
    super

    # Mark all instances no longer found as unknown
    self.raw_power_state = "unknown"
    save
  end

  #
  # EC2 interactions
  #

  def set_custom_field(key, value)
    with_provider_object do |instance|
      tags = instance.create_tags ({
        tags: [
                {
                  key: key,
                  value: value,
                },
              ],
      })
      tags.find{|tag| tag.key == key}.value == value
    end
  end

  def self.calculate_power_state(raw_power_state)
    # http://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_InstanceState.html
    POWER_STATES[raw_power_state.to_s] || "terminated"
  end

  def self.display_name(number = 1)
    n_('Instance (Amazon)', 'Instances (Amazon)', number)
  end
end
