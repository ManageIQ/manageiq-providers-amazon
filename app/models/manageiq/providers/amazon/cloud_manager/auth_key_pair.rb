class ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair < ManageIQ::Providers::CloudManager::AuthKeyPair
  supports :create
  supports :delete

  def self.raw_create_key_pair(ext_management_system, create_options)
    ec2 = ext_management_system.connect
    kp = if create_options["public_key"].blank?
           ec2.create_key_pair(:key_name => create_options["name"])
         else
           ec2.import_key_pair(:key_name => create_options["name"], :public_key_material => create_options["public_key"])
         end

    {:name => kp.name, :fingerprint => kp.key_fingerprint, :auth_key => kp.try(:key_material)}
  rescue => err
    _log.error "keypair=[#{name}], error: #{err}"
    raise MiqException::Error, err.to_s, err.backtrace
  end

  def raw_delete_key_pair
    ec2 = resource.connect
    kp = ec2.key_pair(name)
    kp.delete
  rescue => err
    _log.error "keypair=[#{name}], error: #{err}"
    raise MiqException::Error, err.to_s, err.backtrace
  end
end
