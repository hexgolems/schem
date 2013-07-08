# encoding: utf-8

module Configer
  class Value

    attr_accessor :name, :docu, :value

    def has_valid_type?
      return  @type && @type.respond_to?(:to_config_s) && @type.respond_to?(:from_config_s)
    end

    def set_value(val)
      type_mismatch = @type && !val.is_a?(@type) && !@type.include?(Configer::DummyType)
      raise "invalid value #{val}(#{val.class}) for type #{@type}" if type_mismatch
      return @value = val
    end

    def from_config_s(value)
      return @value = @type.from_config_s(value) if has_valid_type?() && value.is_a?(String)
      return @value = value
    end

    def to_config_s
      is_typed =  has_valid_type? && (@value.is_a?(@type) || @type.include?(Configer::DummyType))
      return @type.to_config_s(@value) if is_typed
      return @value
    end

    def to_json_hash
      h =  {}
      h["##{@name}_desc"] = @docu if @docu
      h[@name] = to_config_s
      return h
    end

# rubocop:disable MethodLength
    def initialize(params)
      @name, @type, @default, @value, @docu = nil, nil, nil, nil, nil
      params.each_pair do |key, value|
        case key
        when :name then @name = value
        when :type then @type = value
        when :default
          @default = value
          set_value(value)
        when :docu then @docu = value
        else
          raise "unknown parameter Value#{key}"
        end
      end
    end
# rubocop:enable MethodLength

  end
end
