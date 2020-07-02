# frozen_string_literal: true

begin
  require 'awesome_print'
rescue LoadError
end

namespace 'aws:extract' do
  desc 'Get / renew instance types and details list from AWS Price List Bulk API'
  task :instance_types do
    require_relative 'lib/aws_products_data_collector'
    require_relative 'lib/aws_instance_data_parser'

    data_dir = ManageIQ::Providers::Amazon::Engine.root.join('db/fixtures')
    data_dir.mkpath
    out_file = data_dir.join('aws_instance_types.yml')

    # weird cache logging issue workaround
    I18n.backend = I18n.backend.backend unless Rails.initialized?

    LOGGER = Logger.new(STDOUT)
    LOGGER.info("NOTE: use 'aws:cache:clear' task to clear the cache")
    AwsProductsDataCollector.cache.logger = LOGGER

    def log_data(header, data, level: :warn)
      severity = Logger.const_get(level.to_s.upcase)
      LOGGER.log(severity) do
        lines = []
        lines << header
        lines << (defined?(AwesomePrint) ? data.ai : JSON.pretty_generate(data))
        lines.join("\n")
      end unless data.empty?
    end

    # prevent global namespace and memory pollution
    def isolated
      yield
    end

    ## get instance types list from github

    # using python sdk, as it contains more historical data than ruby-sdk
    SDK_REPO_PATH = 'boto/botocore'     # 'aws/aws-sdk-ruby'
    SDK_DATA_DIR  = 'botocore/data/ec2' # 'apis/ec2'
    SDK_FILE_NAME = 'service-2.json'    # 'api-2.json'

    GH_API_HOST = 'api.github.com'
    GH_API_HEADERS = { 'Accept' => 'application/vnd.github.v3+json' }.tap do |headers|
      if (api_token = ENV['GITHUB_API_TOKEN'])
        headers.merge!('Authorization' => "token #{api_token}")
      else
        LOGGER.warn 'No GitHub API key found in ENV, consider getting one at https://github.com/settings/tokens'
      end
    end.freeze

    GH_RAW_HOST = 'raw.githubusercontent.com'

    GH_CACHE = ActiveSupport::Cache::FileStore.new(Rails.root.join(*%w(tmp aws_cache github)))
    GH_CACHE.logger = LOGGER

    JSON_CONTENT_RE = /\bapplication\/json\b/i

    def http_get(uri, headers = {})
      LOGGER.info "Making request to #{uri}"

      response = Net::HTTP.start(uri.host, :use_ssl => true) do |http|
        http.get(uri.request_uri, headers)
      end

      body = response.body if response.code_type.body_permitted?
      json = response['content-type'] =~ JSON_CONTENT_RE || uri.path.end_with?('json')
      data = JSON.parse(body) if json && body.present?

      unless response.is_a?(Net::HTTPSuccess)
        LOGGER.error data['message'] if data&.key?('message')
        LOGGER.error "Error getting data from #{uri}"
        response.error!
      end

      data.presence || body.presence
    end

    def get_gh_data(uri_path, query_data = {})
      uri = URI::HTTPS.build(
        :host  => GH_API_HOST,
        :path  => "/repos/#{SDK_REPO_PATH}/#{uri_path}",
        :query => (query_data.to_query unless query_data.empty?),
        )
      http_get(uri, GH_API_HEADERS)
    end

    def get_gh_file(file_path, sha: nil)
      if sha.blank?
        commits = get_gh_data('commits', :path => file_path, :page => 1, :per_page => 1)
        sha = commits[0]['sha']
        LOGGER.debug "Latest commit SHA of '#{file_path}' file is #{sha}"
      end

      GH_CACHE.fetch("#{file_path}.#{sha}".tr('/', '.')) do
        path = "/#{SDK_REPO_PATH}/#{sha}/#{file_path}"
        http_get(URI::HTTPS.build(:host => GH_RAW_HOST, :path => path))
      end
    end

    discontinued_types, types_list = isolated do
      previous_list = []
      versions = get_gh_data("contents/#{SDK_DATA_DIR}")
      versions = versions.lazy.select { |v| v['type'] == 'dir' }.map { |v| v['name'] }.sort
      all, new = versions.reduce([[], []]) do |(all, new), version|
        data = get_gh_file("#{SDK_DATA_DIR}/#{version}/#{SDK_FILE_NAME}")
        data = data['shapes']['InstanceType']['enum']
        old_minus_new = previous_list - data
        new_minus_old = data - previous_list
        log_data("AWS EC2 SDK data version #{version} removed types:", old_minus_new)
        log_data("AWS EC2 SDK data version #{version} added types:", new_minus_old, level: :info)
        previous_list = data
        [all | data, data]
      end
      [all - new, new]
    end

    ## get, parse, and sort data

    types_data, collecting_warnings, parsing_warnings = isolated do
      products_data, collecting_warnings = AwsProductsDataCollector.new(
        :service_name => 'AmazonEC2',
        :product_families => 'Compute Instance', # 'Dedicated Host' == bare metal: "m5", "p3", etc.
        :product_attributes => AwsInstanceDataParser::REQUIRED_ATTRIBUTES,
        :folding_attributes => 'instanceType',
        :mutable_attributes => %w(currentVersion currentGeneration),
        ).result

      parsing_warnings = {}

      types_data = products_data.map do |product_data|
        instance_data, warnings = AwsInstanceDataParser.new(product_data).result
        parsing_warnings.merge!(warnings) { |_, old, new| old + new }
        [product_data['instanceType'], instance_data.deep_dup]
      end.to_h

      [types_data, collecting_warnings, parsing_warnings]
    end

    ## consider previous data

    old_types_data = YAML.load_file(out_file)
    types_list = types_list | old_types_data.keys | types_data.keys

    default_type = old_types_data.find { |_, data| data[:default] }.first
    discontinued_types |= (old_types_data.keys - types_data.keys)
    types_data.merge!(old_types_data.slice(*discontinued_types))

    ## postprocess

    types_data.sort_by! do |instance_type, instance_data|
      instance_data.except!(*%i(default deprecated discontinued disabled))
      instance_data[:default] = true if instance_type == default_type
      if discontinued_types.include?(instance_type) || !instance_data[:current_version]
        instance_data[:discontinued] = true
        instance_data[:disabled] = true
      end
      if instance_data[:current_version] && !instance_data[:current_generation]
        instance_data[:deprecated] = true
      end
      types_list.index(instance_type) || 1_000_000
    end

    ## show warnings

    unknown_types = types_list - (types_data.keys & types_list)

    unless collecting_warnings.empty?
      info = collecting_warnings.transform_keys(&:first)
      info.each_value do |instance_data|
        instance_data.transform_values!(&:to_a)
      end
      info = info.sort_by! do |instance_type, _|
        types_list.index(instance_type) || 1_000_000
      end
      log_data('Attention! Contradictory products data:', info)
    end
    log_data('Attention! Unforeseen values format:', parsing_warnings)
    log_data('Attention! Undeclared or unknown instance types:', unknown_types)

    ## generate update report

    isolated do
      report_date = Time.now.utc.to_datetime
      report_name = "instance_types_diff_#{report_date.strftime('%Y-%m-%d-%H-%M-%S')}.html"
      report_file = Rails.root.join('tmp', report_name)

      old = old_types_data.deep_dup
      new = types_data.deep_dup

      report = +''
      report << '<html>'
      report << '<head>'
      report << '<meta charset="utf-8">'
      report << '<style>'
      report << 'table{width:100%}'
      report << 'th,td{width:36%}'
      report << 'th,td:first-child{width:28%}'
      report << 'th,td{border:1px dotted gray}'
      report << '.added{background-color:rgb(223,240,216)}'
      report << '.removed{background-color:rgb(242,222,222)}'
      report << '.changed{background-color:rgb(252,248,227);}'
      report << '</style>'
      report << '</head>'
      report << '<body>'
      report << '<h1>Generated: <script>'
      report << "document.write(new Date('#{report_date.iso8601}').toString())"
      report << '</script></h1>'

      NIL_MARK = '<em>nil</em>'

      (new.keys | old.keys).each do |instance_type|
        old_data = old.delete(instance_type)
        new_data = new.delete(instance_type)

        [old_data, new_data].compact.each do |data|
          data.each_value { |v| v.sort! if v.is_a? Array }
        end

        in_the_old = (old_data.to_a - new_data.to_a).to_h
        in_the_new = (new_data.to_a - old_data.to_a).to_h

        unless (attrs = in_the_old.keys | in_the_new.keys).empty?
          report << '<table>'
          report << "<caption><h2>#{instance_type}</h2></caption>"
          report << '<tr><th>Attribute</th><th>Old value</th><th>New value</th></tr>'

          attrs.each do |attr|
            row_class =
              case
              when !in_the_old.key?(attr) && in_the_new.key?(attr)
                added = true
                'added'
              when in_the_old.key?(attr) && !in_the_new.key?(attr)
                removed = true
                'removed'
              else
                changed = true
                'changed'
              end

            old_value = in_the_old.delete(attr)
            new_value = in_the_new.delete(attr)

            if changed && (old_value.present? || old_value == false) && new_value.nil?
              new_value_class = ' class="removed"'
            end

            old_value = NIL_MARK if (changed || removed) && old_value.nil?
            new_value = NIL_MARK if (changed || added)   && new_value.nil?

            report << "<tr class=\"#{row_class}\">"
            report << "<td>#{attr}</td>"
            report << "<td>#{old_value}</td>"
            report << "<td#{new_value_class}>#{new_value}</td>"
            report << '</tr>'
          end

          report << "</table>"
        end
      end

      report << '</body></html>'
      report_file.write(report)

      LOGGER.info "report file: #{report_file.to_path}"
    end

    ## save data

    out_file.write(types_data.to_yaml.each_line.map(&:rstrip).join("\n") << "\n")
  end
end
