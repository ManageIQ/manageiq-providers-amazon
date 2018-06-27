class ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair < ManageIQ::Providers::CloudManager::AuthKeyPair
  AwsKeyPair = Struct.new(:name, :key_name, :fingerprint, :private_key)

  def self.raw_create_key_pair(ext_management_system, create_options)
    ec2 = ext_management_system.connect
    kp = if create_options[:public_key].blank?
           ec2.create_key_pair(:key_name => create_options[:name])
         else
           ec2.import_key_pair(:key_name => create_options[:name], :public_key_material => create_options[:public_key])
         end

    AwsKeyPair.new(kp.name, kp.name, kp.key_fingerprint, kp.try(:key_material))
  rescue => err
    _log.error "keypair=[#{name}], error: #{err}"
    raise MiqException::Error, err.to_s, err.backtrace
  end

  def self.validate_create_key_pair(ext_management_system, _options = {})
    if ext_management_system
      {:available => true, :message => nil}
    else
      {:available => false,
       :message   => _("The Keypair is not connected to an active %{table}") %
         {:table => ui_lookup(:table => "ext_management_system")}}
    end
  end

  def raw_delete_key_pair
    ec2 = resource.connect
    kp = ec2.key_pair(name)
    kp.delete
  rescue => err
    _log.error "keypair=[#{name}], error: #{err}"
    raise MiqException::Error, err.to_s, err.backtrace
  end

  def validate_delete_key_pair
    {:available => allow_delete?, :message => nil}
  end

  private

  # Returns false if an auth_key is available true if not.
  # Meaning we can delete if there is no auth_key.
  def allow_delete?
    !self.auth_key.present?
  end
end
