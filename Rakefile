require 'bundler/setup'
require 'bundler/gem_tasks'

begin
  require 'rspec/core/rake_task'

  APP_RAKEFILE = File.expand_path("../spec/manageiq/Rakefile", __FILE__)
  load 'rails/tasks/engine.rake'
rescue LoadError
end

namespace :spec do
  task :setup => 'app:test:providers:amazon:setup'
end

task :spec => 'app:test:providers:amazon'
task :default => :spec
