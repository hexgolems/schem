# encoding: utf-8
require_relative './../include.rb'

module Schem
  class MemorySection
    attr_reader :from, :to, :offset, :length, :flags, :image, :object_file

    def initialize(from, to, length = :unkown, offset = :unkown, object_file = :unkown, flags = :unkown, image = :unkown)
      @from = from
      @to = to
      @offset = offset
      @length = length
      @flags = flags
      @image = image
      @object_file = object_file
    end

    def intersection(rangeb)
      res = ([from, rangeb.min].max..[to, rangeb.max].min)
      return nil if res.first > res.last
      res
    end

    def ==(other)
      return false unless other.class == MemorySection
      return false if @from != other.from
      return false if @to != other.to
      return false if @offset != other.offset
      return false if @length != other.length
      return false if @flags != other.flags
      return false if @image != other.image
      return false if @object_file != other.object_file
      true
    end
  end
end
