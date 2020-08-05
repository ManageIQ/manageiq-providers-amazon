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

  s.add_dependency "aws-sdk-core",                 ">= 3.104.3"
  s.add_dependency "aws-sdk-cloudformation",       "~> 1.0"
  s.add_dependency "aws-sdk-cloudwatch",           "~> 1.0"
  s.add_dependency "aws-sdk-ec2",                  "~> 1.0"
  s.add_dependency "aws-sdk-elasticloadbalancing", "~> 1.0"
  s.add_dependency "aws-sdk-iam",                  "~> 1.0"
  s.add_dependency "aws-sdk-s3",                   "~> 1.0"
  s.add_dependency "aws-sdk-servicecatalog",       "~> 1.0"
  s.add_dependency "aws-sdk-sns",                  "~> 1.0"
  s.add_dependency "aws-sdk-sqs",                  "~> 1.0"

  s.add_development_dependency "codeclimate-test-reporter", "~> 1.0.0"
  s.add_development_dependency "simplecov"
end
