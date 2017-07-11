class ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair < ManageIQ::Providers::CloudManager::AuthKeyPair
  def self.raw_create_key_pair(ext_management_system, create_options)
    ec2 = ext_management_system.connect
    kp = ec2.create_key_pair(create_options)
    AwsKeyPair = Struct.new(:name, :key_name, :fingerprint, :private_key)
    AwsKeyPair.new(kp.name, kp.name, kp.key_fingerprint, kp.key_material)
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
    {:available => true, :message => nil}
  end
end
