require "codeclimate-test-reporter"
CodeClimate::TestReporter.start
VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com'
  config.cassette_library_dir = File.join(ManageIQ::Providers::Amazon::Engine.root, 'spec/vcr_cassettes')
end
