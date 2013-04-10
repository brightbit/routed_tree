require 'json'

class RoutedTree
  class << self
    def [](contents)
      new contents: contents
    end

    def router
      @router ||= Mapper.new(self)
    end

    def config(&block)
      self.class_eval(&block)
    end
  end

  def initialize(*args)
    options = args.last.is_a?(Hash) ? args.pop : nil
    @parent = options && options.delete(:parent)
    @contents = (options && options.delete(:contents)) || (@parent && @parent.contents(*args))
    @route = []
    if parent && parent.class == self.class
      @route += args.compact #.map { |part| key_untransform(part) }
    end
    @memo = {}
  end

  attr_reader :parent, :route

  def full_route
    @full_route ||= (parent && parent.class == self.class ? parent.full_route : []) + @route
  end

  def key_transform(key)
    #override this to convert keys to a different format on read.
    key
  end

  def key_untransform(key)
    #override this to convert keys to a different format on read.
    key
  end

  def internal_key(key)
    key.is_a?(Integer) ? key : key_transform(key)
  end

  def [](*keys)
    # Don't use ||= here. @memo[key] could contain something falsey.
    return @memo[keys] if @memo.has_key?(keys)

    @memo[keys] = case
    when (factory = router.factory_for(*full_route, *keys))
      factory.(*keys, parent: self)
    when contents(*keys).is_a?(Enumerable)
      child_class.new(*keys, parent: self)
    else
      contents(*keys)
    end
  end

  def contents(*keys)
    [*keys].inject(@contents) do |memo, key|
      begin
        memo &&
        if memo.is_a?(Array)
          memo[key.to_i]
        else
          # Yuck. Need to normalize keys for comparison.
          memo[key_transform(key)] || memo[key.to_s] || memo[key.to_sym]
        end
      rescue Exception => e
        raise e.class.new(
          "#{e.class}: Could not access key #{internal_key(key).inspect} " +
          "in #{memo.inspect} (keys passed: #{keys.inspect})"
        )
      end
    end
  end

  def self.child_class
    self
  end

  def child_class
    self.class.child_class
  end

  def []=(key, value)
    contents[key_transform(key)] = value
  end

  def <<(item)
    contents << item
  end

  include Enumerable

  def each
    if hash_like?
      keys.each do |key|
        ukey = key_untransform(key)
        yield ukey, self[ukey]
      end
    elsif array_like?
      contents.each_index { |i| yield self[i] }
    end
  end

  def has_key?(key)
    keys.include?(key)
  end

  def keys
    if !hash_like?
      raise NoMethodError.new("cannot call `keys' on #{self}, since it does not wrap a hash")
    else
      [].tap do |ret|
        if routes
          ret.concat(child_keys)
        end
        if contents.respond_to?(:keys)
          ret.concat(contents.keys.map { |k| key_untransform(k) })
        end
      end
    end
  end

  def serializeable_array
    return nil unless array_like?

    [].tap do |ret|
      each do |item|
        ret << if item.respond_to?(:serializeable)
          item.serializeable
        else
          item
        end
      end
    end
  end

  def serializeable_hash
    return nil unless hash_like?

    {}.tap do |ret|
      each do |k, v|
        ret[k] = if v.respond_to?(:serializeable)
          v.serializeable
        else
          v
        end
      end
    end
  end

  def serializeable
    serializeable_array || serializeable_hash
  end

  def to_json
    JSON.dump serializeable
  end

  def array_like?
    @contents.is_a?(Array)
  end

  def hash_like?
    !array_like? && (@contents.respond_to?(:keys) || child_keys.count > 0)
  end

  def method_missing(method, *args)
    if contents.respond_to?(method)
      # This works for many array & hash methods like #length, #empty?, etc.
      contents.send(method, *args)
    else
      super
    end
  end

  def respond_to?(method)
    if [:keys, :has_key?].include?(method)
      hash_like?
    else
      super || contents.respond_to?(method)
    end
  end

  def router
    self.class.router
  end

  def routes
    router.relative_routes(*full_route)
  end

  def child_keys
    if !routes
      []
    else
      routes.keys.select do |k|
        k.to_s !~ /^_/ &&

        # Only include keys that contain real content
        #   (in case of mappings for which this instance provides no
        #    applicable content)
        self[k] && (
          !self[k].respond_to?(:contents) ||
          self[k].contents                ||
          self[k].hash_like? && self[k].keys.any?
        )
      end
    end
  end
end
