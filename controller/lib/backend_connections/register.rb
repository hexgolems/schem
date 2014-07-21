# encoding: utf-8
require_relative './../include.rb'

module Schem
  class Register
    attr_reader :name, :value, :size, :parent, :offset

    def initialize(name, value, size = nil, parent = nil, offset = nil)
      @name = name
      @value = value
      @size = size
      @parent = parent
      @offset = offset
    end

    def ==(other)
      return false unless other.class == Breakpoint
      return false if @name != other.name
      return false if @value != other.value
      return false if @size != other.size
      return false if @parent != other.parent
      return false if @offset != other.parent
      true
    end
  end
end
