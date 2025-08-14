module ManageIQ
  module Providers
    module Amazon
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::Amazon

        config.autoload_paths << root.join('lib')

        def self.vmdb_plugin?
          true
        end

        def self.plugin_name
          _('Amazon Provider')
        end

        def self.init_loggers
          $aws_log ||= Vmdb::Loggers.create_logger("aws.log")
        end

        def self.apply_logger_config(config)
          Vmdb::Loggers.apply_config_value(config, $aws_log, :level_aws)
        end
      end
    end
  end
end
