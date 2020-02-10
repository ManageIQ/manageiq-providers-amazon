def with_aws_stubbed(stub_responses_per_service)
  require "aws-sdk-core"
  stub_responses_per_service.each do |service, stub_responses|
    if Aws.config.dig(service, :stub_responses).present?
      raise "Aws.config[#{service}][:stub_responses] already set"
    else
      require "aws-sdk-#{service.to_s.downcase}"
      (Aws.config[service] ||= {})[:stub_responses] = stub_responses
    end
  end
  yield
ensure
  stub_responses_per_service.keys.each do |service|
    Aws.config[service].delete(:stub_responses)
  end
end
