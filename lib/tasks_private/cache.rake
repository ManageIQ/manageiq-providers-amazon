# frozen_string_literal: true

namespace 'aws:cache' do
  desc 'Clear AWS data cache'
  task :clear do
    ActiveSupport::Cache::FileStore.new(Rails.root.join(*%w(tmp aws_cache))).clear
  end
end
