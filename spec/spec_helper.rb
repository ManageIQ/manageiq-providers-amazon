if ENV['CI']
  require "codeclimate-test-reporter"
  CodeClimate::TestReporter.start
end

VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com' if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::Amazon::Engine.root, 'spec/vcr_cassettes')
end

Dir[Rails.root.join("spec/shared/**/*.rb")].each { |f| require f }
