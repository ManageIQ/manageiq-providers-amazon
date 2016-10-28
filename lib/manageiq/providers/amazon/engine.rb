module ManageIQ
  module Providers
    module Amazon
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::Amazon
      end
    end
  end
end
