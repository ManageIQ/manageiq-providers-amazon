module ManageIQ::Providers::Amazon::CloudManager::VmOrTemplateShared
  extend ActiveSupport::Concern
  include_concern 'Scanning'
end
