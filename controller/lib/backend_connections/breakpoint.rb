# encoding: utf-8
require_relative './../include.rb'

module Schem
  class Breakpoint
    attr_accessor :type, :enabled, :address, :internal_representation

    def initialize(type, enabled, address, internal_representation)
      @type = type
      @enabled = enabled
      @address = address
      @internal_representation = internal_representation
    end

    def enable
      unless @enabled
        new_bp = @api.internal_bp_create(@address)
        @internal_representation = new_bp.internal_representation
      end
    end

    def disable
      if @enabled
        @api.internal_bp_del(self)
        @internal_representation = nil
      end
    end

    def delete
      @api.internal_bp_delete(self)
    end

    def ==(other)
      return false unless other.class == Breakpoint
      return false if @type != other.type
      return false if @enabled != other.enabled
      return false if @address != other.address
      return false if @internal_representation != other.internal_representation
      true
    end
  end
end
