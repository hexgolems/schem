# encoding: utf-8
module Configer
  class Map
# rubocop:disable MethodLength
    def initialize(params, config)
      @children = {}
      @config = config
      @name, @docu = nil, nil
      params.each_pair do |key, value|
        case key
        when :name
          @name = value
        when :docu
          @docu = value
        else
          raise "unknown parameter for a Map #{key}"
        end
      end
    end
# rubocop:enable MethodLength

    attr_accessor :name, :docu

    def get_child(name)
      child = @children[name]
      return child.value if child.is_a?(Value)
      return child
    end

# rubocop:disable IfUnlessModifier
    def to_json(*a)
      hash = {}
      @children.each_pair do |k, v|
        if v.is_a? Value
          v.to_json_hash.each_pair { |vk, vv| hash[vk] = vv }
        elsif v.is_a? Map
          hash["##{v.name}_desc"] = v.docu if v.docu
          hash[k] = v
        end
      end
      return hash.to_json(*a)
    end
# rubocop:enable IfUnlessModifier

    def from_hash(hash)
      raise 'from hash can only be called with a Hash' unless hash.is_a? Hash
      hash.each_pair do |key, val|
        if @children.include?(key) && @children[key].is_a?(Map) && val.is_a?(Hash)
          @children[key].from_hash(val)
        elsif @children.include?(key) && @children[key].is_a?(Value)
          @children[key].from_config_s(val)
        else
          raise "unknown config option #{key}:#{val}" unless key =~ /\A#.*_desc\Z/
        end
      end
    end

    def has_child?(name)
      @children.include? name
    end

    def add_value(other)
      @children[other.name] = other
    end

    def assign_child(name, value)
      child = @children[name]
      raise 'cannot set value for a config categorie' unless child.is_a? Value
      child.set_value(value)
      @config.update(child)
    end

    def method_missing(name, *params, &block)

      name_s = name.to_s

      return get_child(name_s) if has_child?(name_s) && params == [] && block == nil

      if name_s =~ /[^=]+=\Z/
        if has_child?(name_s[0..-2]) && params.length == 1 && block == nil
          assign_child(name_s[0..-2], params[0])
          return params[0]
        end
      end

      super
    end
  end
end
