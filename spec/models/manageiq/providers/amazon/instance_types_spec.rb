describe ManageIQ::Providers::Amazon::InstanceTypes do
  class Attribute
    attr_accessor :key, :key_other, :processor, :other_proc
    attr_accessor :convert, :other_convert
    def initialize(key)
      if key.is_a? Hash
        self.key, self.key_other = key.first
      else
        self.key = self.key_other = key
      end
      yield self if block_given?
      # self.key_other = key_other || key
      # self.processor = processor
    end

    def other_proc(&block)
      self.other_proc = block
      self
    end

    def fetch(instance, key)
      if processor
        processor.call(instance.fetch(key))
      else
        instance.fetch(key)
      end
    end

    def same?(a, b)
      av, bv = a[key], b[key_other]
      av = convert.to_proc.call(av) if convert
      bv = convert.to_proc.call(bv) if convert
      bv = other_convert.to_proc.call(bv) if other_convert
      av == bv
    end

    def format(instance)
      %Q(:#{key} => "#{fetch(instance, key_other)}")
    end
  end

  def format_instance(instance, current_instance, attributes)
    puts %Q("#{instance[:instance_type]}" => {)
    attributes.each do |key|
      if current_instance
        unless key.same?(current_instance, instance)
          puts key.format(instance)
          puts %Q(# was: #{current_instance[key.key]})
        end
      else
        puts key.format(instance)
      end
    end
    puts '}'
  end

  it "is the same" do
    require 'open-uri'

    attributes = [
      Attribute.new(:name => :instance_type),
      Attribute.new(:family) {|a| a.convert = :downcase },
      Attribute.new(:description => :pretty_name) {|a| a.convert = :downcase},
      Attribute.new(:memory) do |a|
        a.convert = :to_f
        a.other_convert = Proc.new do |v|
          v.to_f.gigabytes
        end
      end,
      Attribute.new(:vcpu => :vCPU),
    ]

    find_instance = Proc.new do |o|
      described_class.all.find do |i|
        attributes.all?{|a| a.same?(i, o)}
      end
    end

    current_instance = Proc.new do |o|
      described_class.all.find{|i| i[:name] == o[:instance_type]}
    end

    # download this to /tmp/instances.json
    # instances = YAML.safe_load(open('https://raw.githubusercontent.com/powdahound/ec2instances.info/master/www/instances.json').read)
    instances = YAML.safe_load(open('/tmp/instances.json').read)
    instances.each do |instance|
      instance.deep_symbolize_keys!
      find_instance.call(instance) or
        format_instance(instance, current_instance.call(instance), attributes)
    end

  end

end
