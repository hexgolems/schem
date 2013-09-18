# TODO document me
module Schem

  # TODO document me
  class ConversionService < BaseService

    def initialize(*args)
      super
    end

    UNSIGNED = {8 => 'C', 16 => 'S', 32 => 'L', 64 => 'Q'}
    SIGNED = {8 => 'c', 16 => 's', 32 => 'l', 64 => 'q'}

    def parse_signed(mem)
      length = mem.length * 8
      format = SIGNED[length]
      raise "Cannot parse #{length} bit integer" unless format
      mem.unpack(format).first
    end

    def parse_unsigned(mem)
      length = mem.length * 8
      format = UNSIGNED[length]
      raise "Cannot parse #{length} bit integer" unless format
      mem.unpack(format).first
    end

    def dump_unsigned(value, length)
      format = UNSIGNED[length]
      raise "Cannot dump #{length} bit integer" unless format
      [value].pack(format)
    end

    def dump_signed(value, length)
      format = SIGNED[length]
      raise "Cannot dump #{length} bit integer" unless format
      [value].pack(format)
    end

    def to_hex(value, reg_length)
      return unless value
      to_unsigned(value, reg_length).to_s(16).rjust(reg_length/8, '0')
    end

    def to_signed(value, reg_length)
      return unless value
      parse_signed(dump_unsigned(value,reg_length))
    end

    def to_unsigned(value, reg_length)
      return unless value
      parse_unsigned(dump_unsigned(value,reg_length))
    end

    def repr(value, reg_length)
      return unless value
      return {hex: to_hex(value,reg_length), signed: to_signed(value,reg_length), unsigned: to_unsigned(value,reg_length)}
    end

  end
  register_service(:int, ConversionService)
end
