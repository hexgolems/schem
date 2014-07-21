# encoding: utf-8
require_relative './../include.rb'

module Schem
  class ImageSection
    attr_reader :from, :to, :at, :length, :name, :flags, :object_file

    def initialize(from, to, at, length, name, flags, object_file)
      @from = from
      @to = to
      @at = at
      @length = length
      @name = name
      @flags = flags
      @object_file = object_file
    end

    def intersection(rangeb)
      res = ([from, rangeb.min].max .. [to, rangeb.max].min)
      return nil if res.first > res.last
      res
    end

    def ==(other)
      return false unless other.class == MemorySection
      return false if @from != other.from
      return false if @to != other.to
      return false if @at != other.at
      return false if @length != other.length
      return false if @name != other.name
      return false if @flags != other.flags
      return false if @object_file != other.object_file
      true
    end
  end
end
