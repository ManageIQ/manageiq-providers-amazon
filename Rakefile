begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

APP_RAKEFILE = File.expand_path("../spec/manageiq/Rakefile", __FILE__)
load 'rails/tasks/engine.rake'

namespace :spec do
  task :setup => 'app:test:providers:amazon:setup'
end

task :spec => 'app:test:providers:amazon'
task :default => :spec
