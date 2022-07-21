class ManageIQ::Providers::Amazon::CloudManager::CloudDatabase < ::CloudDatabase
  supports :create
  supports :delete

  def self.params_for_create(ems)
    {
      :fields => [
        {
          :component  => 'text-field',
          :id         => 'name',
          :name       => 'name',
          :label      => _('Cloud Database Name'),
          :isRequired => true,
          :validate   => [{:type => 'required'}],
        },
        {
          :component  => 'text-field',
          :name       => 'storage',
          :id         => 'storage',
          :label      => _('Storage (in Gigabytes)'),
          :type       => 'number',
          :step       => 1,
          :isRequired => true,
          :validate   => [{:type => 'required'},
                          {:type => 'min-number-value', :value => 1, :message => _('Size must be greater than or equal to 1')}],
        },
        {
          :component    => 'select',
          :name         => 'flavor',
          :id           => 'flavor',
          :label        => _('Cloud Database Instance Class'),
          :includeEmpty => true,
          :isRequired   => true,
          :validate     => [{:type => 'required'}],
          :options      => ems.cloud_database_flavors.active.map do |db|
            {
              :label => db[:name],
              :value => db[:name],
            }
          end,
        },
        {
          :component    => 'select',
          :name         => 'database',
          :id           => 'database',
          :label        => _('Cloud Database'),
          :includeEmpty => true,
          :isRequired   => true,
          :validate     => [{:type => 'required'}],
          :options      => ["aurora", "aurora-mysql", "aurora-postgresql", "mariadb", "postgres", "mysql", "oracle-ee", "oracle-ee-cdb", "oracle-se2", "oracle-se2-cdb", "sqlserver-ee", "sqlserver-se", "sqlserver-ex", "sqlserver-web"].map do |db|
            {
              :label => db,
              :value => db,
            }
          end,
        },
        {
          :component => 'text-field',
          :id        => 'username',
          :name      => 'username',
          :label     => _('Master Username'),
        },
        {
          :component => 'password-field',
          :type      => 'password',
          :id        => 'password',
          :name      => 'password',
          :label     => _('Master Password'),
        },
      ],
    }
  end

  def self.raw_create_cloud_database(ext_management_system, options)
    options.symbolize_keys!
    ext_management_system.with_provider_connection(:service => :RDS) do |connection|
      connection.client.create_db_instance(:db_instance_identifier => options[:name],
                                           :db_instance_class      => options[:flavor],
                                           :allocated_storage      => options[:storage],
                                           :engine                 => options[:database],
                                           :master_username        => options[:username],
                                           :master_user_password   => options[:password])
    end
  rescue => e
    _log.error("cloud_database=[#{name}], error: #{e}")
    raise
  end

  def raw_delete_cloud_database
    with_provider_connection(:service => :RDS) do |connection|
      connection.client.delete_db_instance(:db_instance_identifier => name, :skip_final_snapshot => true)
    end
  rescue => err
    _log.error("cloud database=[#{name}], error: #{err}")
    raise
  end
end
