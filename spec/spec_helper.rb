if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

Dir[Rails.root.join("spec/shared/**/*.rb")].each { |f| require f }
Dir[File.join(__dir__, "support/**/*.rb")].each { |f| require f }

require "manageiq-providers-amazon"

VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com' if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::Amazon::Engine.root, 'spec/vcr_cassettes')
  config.define_cassette_placeholder(Rails.application.secrets.amazon_eks_defaults[:hostname]) do
    Rails.application.secrets.amazon_eks[:hostname]
  end
  config.define_cassette_placeholder(Rails.application.secrets.amazon_defaults[:client_id]) do
    Rails.application.secrets.amazon[:client_id]
  end
end
