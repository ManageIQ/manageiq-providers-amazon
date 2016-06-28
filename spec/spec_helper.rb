require "codeclimate-test-reporter"
CodeClimate::TestReporter.start
VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com'
end
