class ManageIQ::Providers::Amazon::Inventory::HashCollection
  attr_reader :collection

  def initialize(collection)
    @collection = collection
  end

  def each
    collection.each { |item| yield(transform(item)) }
  end

  def all
    collection.each_with_object([]) { |item, obj| obj << transform(item) }
  end

  private

  def transform(item)
    transform_keys(item.respond_to?(:to_hash) ? item.to_hash : item.data.to_hash)
  end

  def transform_keys(value)
    case value
    when Array
      value.map { |x| transform_keys(x) }
    when Hash
      Hash[value.map { |k, v| [k.to_s.underscore, transform_keys(v)] }]
    else
      value
    end
  end
end
