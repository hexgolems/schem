# encoding: utf-8
# BIT - bitmap for inferred types
#
# TYPES           Binary
# undefined       000
# instruction     001
# pointer         010
# string          011
# int_8           100
# int_16          101
# int_32          110
# int_64          111
#
# FLAG            BIT     Value
# continued       4       1 if it is a continued type 0 if it is the first element of a type
# signed          5       1 if signed 0 if unsigned
# struct          6       1 if it is part of a struct 0 if not
#
# TODO structs!
#
require 'pry'
require_relative '../bit.rb'

module Schem
  # Service for storing and retrieving inferred types
  class TypeInformationBitmapService < BaseService
    attr_accessor :bitmaps

    def initialize(*args)
      @bitmaps = {}
      super
    end

    def find_bitmap(range)
      range = (range..range) if range.class != Range
      keys = @bitmaps.keys
      keys = keys.select { |x| @bitmaps[x].range.intersection(range) == range }
      fail "found #{keys.length} bitmaps" unless keys.length <= 1
      bitmap = @bitmaps[keys.first]
      bitmap
    end

    def get_as_disasm_type(address)
      type = get(address)
      return nil unless type
      address = type.address
      range = (address...(address + (type.length)))
      case type.type
        when :string then StringType.new(srv, range)
        when :int8, :int16, :int32, :int64, :pointer then IntegerType.new(srv, range, type.signed)
        when :instruction then InstructionType.new(srv, range)
      end
    end

    def set(address, type, length)
      bit = srv.bit.find_bitmap(address)
      return false unless bit
      bit.set_type(address, type, length)
      true
    end

    def get(address)
      getrange(address..address).first
    end

    def getrange(range)
      t = find_bitmap(range)
      return [] unless t
      types = t.types(range)
      types
    end

    register_service(:bit, TypeInformationBitmapService)
  end
end
