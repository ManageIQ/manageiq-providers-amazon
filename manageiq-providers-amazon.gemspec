$:.push File.expand_path("../lib", __FILE__)

require "manageiq/providers/amazon/version"

Gem::Specification.new do |s|
  s.name        = "manageiq-providers-amazon"
  s.version     = ManageIQ::Providers::Amazon::VERSION
  s.authors     = ["ManageIQ Developers"]
  s.homepage    = "https://github.com/ManageIQ/manageiq-providers-amazon"
  s.summary     = "Amazon Provider for ManageIQ"
  s.description = "Amazon Provider for ManageIQ"
  s.licenses    = ["Apache-2.0"]

  s.files = Dir["{app,config,lib}/**/*"]

  s.add_dependency "aws-sdk", "~> 3.0.1"

  s.add_development_dependency "codeclimate-test-reporter", "~> 1.0.0"
  s.add_development_dependency "simplecov"
end
