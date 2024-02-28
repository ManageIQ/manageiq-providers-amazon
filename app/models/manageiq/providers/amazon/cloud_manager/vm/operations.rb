module ManageIQ::Providers::Amazon::CloudManager::Vm::Operations
  extend ActiveSupport::Concern
  include Guest
  include Power

  included do
    supports :terminate do
      unsupported_reason(:control)
    end
  end

  def raw_destroy
    raise "VM has no #{ui_lookup(:table => "ext_management_systems")}, unable to destroy VM" unless ext_management_system
    with_provider_object(&:terminate)
    update!(:raw_power_state => "shutting-down")
  end
end
