require 'bundler/setup'
require 'bundler/gem_tasks'
require 'manageiq-providers-amazon'

begin
  require 'rspec/core/rake_task'

  APP_RAKEFILE = File.expand_path("../spec/manageiq/Rakefile", __FILE__)
  load 'rails/tasks/engine.rake'
rescue LoadError
end

ManageIQ::Providers::Amazon::Engine.load_tasks
namespace :spec do
  desc "Setup environment for specs"
  task :setup => 'app:test:providers:amazon:setup'
end

desc "Run all amazon specs"
task :spec => 'app:test:providers:amazon'

task :default => :spec
