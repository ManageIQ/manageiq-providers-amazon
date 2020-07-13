# frozen_string_literal: true

# https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/using-ppslong.html

class AwsProductsDataCollector
  OFFERS_HOSTNAME = 'https://pricing.us-east-1.amazonaws.com'

  cattr_accessor :cache, :instance_writer => false do
    cache_dir = Rails.root.join('tmp', 'aws_cache', 'products_data')
    ActiveSupport::Cache::FileStore.new(cache_dir)
  end

  attr_reader :service_name, :product_families, :product_attributes,
              :folding_attributes, :mutable_attributes

  def initialize(service_name:,
                 product_families:,
                 product_attributes:,
                 folding_attributes:,
                 mutable_attributes: nil)

    @service_name       = service_name
    @product_families   = Array.wrap(product_families).dup.freeze
    @product_attributes = Array.wrap(product_attributes).dup.freeze
    @mutable_attributes = Array.wrap(mutable_attributes).dup.freeze
    @folding_attributes = Array.wrap(folding_attributes).dup.freeze
    @product_attributes = (@folding_attributes + @product_attributes).uniq.freeze

    @parsed = false
  end

  def result
    [products_data, deviations]
  end

  def products_data
    parse! unless @parsed
    @products_data
  end

  def deviations
    parse! unless @parsed
    @warnings
  end

  private

  def parse!
    @parsed_data_cache_key ||= begin
      key_values = product_families + product_attributes + folding_attributes + mutable_attributes
      hexdigest = key_values.reduce(Digest::SHA1.new) { |digest, value| digest << value }.hexdigest
      "#{hexdigest}.#{service_name}.parsed_data.#{offer_versions_digest}"
    end

    result, warnings = cache.fetch(@parsed_data_cache_key) do
      offers_data.each_with_object([{}, {}]) do |product, (memo, deviations)|
        next unless product_families.include?(product['productFamily'])

        item_attrs  = product['attributes'].slice(*product_attributes)
        items_group = item_attrs.fetch_values(*folding_attributes)

        group_data = memo[items_group] ||= {}
        group_data.merge!(item_attrs) do |key, old_value, new_value|
          unless old_value.to_s.casecmp(new_value.to_s).zero? || mutable_attributes.include?(key)
            values = (deviations[items_group] ||= {})[key] ||= Set[old_value]
            values << new_value
          end
          new_value # versions are sorted, taking the freshest value
        end
      end
    end

    @parsed = true
    @warnings = warnings
    @products_data = result.values.each(&:freeze).freeze
  end

  def offers_index_uri
    @offers_index_uri ||= URI("#{OFFERS_HOSTNAME}/offers/v1.0/aws/#{service_name}/index.json")
  end

  def offers_index
    @offers_index ||=
      cache.fetch("#{service_name}.offers_index", :expires_in => 1.hour) do
        JSON.parse(Net::HTTP.get_response(offers_index_uri).body)
      end
  end

  def offer_versions
    @offer_versions ||= offers_index['versions'].sort.to_h.freeze
  end

  def offer_versions_digest
    @offer_versions_digest ||=
      offer_versions.each_key.with_object(Digest::SHA1.new) do |version, digest|
        digest << version
      end.hexdigest
  end

  def offers_version_uri(version_data)
    URI("#{OFFERS_HOSTNAME}#{version_data['offerVersionUrl']}")
  end

  def offers_data
    @offers_data ||=
      cache.fetch("#{service_name}.all_offers_data.#{offer_versions_digest}") do
        current_version = offers_index['currentVersion']
        offer_versions.map do |version_name, version_data|
          data = cache.fetch("#{service_name}.offers_data.#{version_name}") do
            offers_uri = offers_version_uri(version_data)
            json_text = Net::HTTP.get_response(offers_uri).body
            JSON.parse(json_text)['products'].values
          end
          is_current = current_version == version_name
          data.each do |product|
            attributes = product['attributes']
            attributes['currentVersion'] = is_current unless attributes.key?('currentVersion')
          end
        end.reduce(&:+)
      end
  end
end
