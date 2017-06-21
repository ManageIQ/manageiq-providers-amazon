require 'bundler/setup'
require 'bundler/gem_tasks'

begin
  require 'rspec/core/rake_task'

  APP_RAKEFILE = File.expand_path("../spec/manageiq/Rakefile", __FILE__)
  load 'rails/tasks/engine.rake'
rescue LoadError
end

FileList['lib/tasks_private/**/*.rake'].each { |r| load r }

task :default => :spec
