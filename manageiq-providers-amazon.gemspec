# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'manageiq/providers/amazon/version'

Gem::Specification.new do |spec|
  spec.name          = "manageiq-providers-amazon"
  spec.version       = ManageIQ::Providers::Amazon::VERSION
  spec.authors       = ["ManageIQ Authors"]

  spec.summary       = "ManageIQ plugin for the Amazon provider."
  spec.description   = "ManageIQ plugin for the Amazon provider."
  spec.homepage      = "https://github.com/ManageIQ/manageiq-providers-amazon"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk-core",                 "~> 3.114"
  spec.add_dependency "aws-sdk-cloudformation",       "~> 1.0"
  spec.add_dependency "aws-sdk-cloudwatch",           "~> 1.126"
  spec.add_dependency "aws-sdk-ec2",                  "~> 1.0"
  spec.add_dependency "aws-sdk-elasticloadbalancing", "~> 1.0"
  spec.add_dependency "aws-sdk-iam",                  "~> 1.0"
  spec.add_dependency "aws-sdk-rds",                  "~> 1.0"
  spec.add_dependency "aws-sdk-s3",                   "~> 1.0", ">= 1.96.1"
  spec.add_dependency "aws-sdk-servicecatalog",       "~> 1.0"
  spec.add_dependency "aws-sdk-sns",                  "~> 1.0"
  spec.add_dependency "aws-sdk-sqs",                  "~> 1.0"
  spec.add_dependency "net-scp",                      ">= 1.2", "<5"

  spec.add_development_dependency "manageiq-style"
  spec.add_development_dependency "simplecov", ">= 0.21.2"
end
