namespace 'aws:extract' do
  desc 'Get / refresh database_types'
  task :database_types do
    require 'open-uri'

    instances = URI.open("https://instances.vantage.sh/rds/instances.json") do |io|
      JSON.parse(io.read)
    end

    results = instances.map do |instance|
      network_performance = if instance["networkPerformance"].match?(/(\d+ Gigabit)/)
                              :very_high
                            else
                              instance["networkPerformance"].downcase.tr(' ', '_').to_sym
                            end

      result = {
        :name                => instance["instanceType"],
        :family              => instance["instanceFamily"],
        :vcpu                => instance["vcpu"].to_i,
        :memory              => instance["memory"].to_f * 1.gigabyte,
        :ebs_optimized       => instance["dedicatedEbsThroughput"].present?,
        :deprecated          => instance["currentGeneration"] != "Yes",
        :network_performance => network_performance
      }

      [result[:name], result.sort.to_h]
    end.to_h

    File.write(ManageIQ::Providers::Amazon::Engine.root.join("db/fixtures/aws_database_types.yml"), results.sort.to_h.to_yaml)
  end
end
