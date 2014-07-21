# encoding: utf-8
require_relative './../include.rb'

module Schem
  module BreakpointWrapper
    def init_bp_wrapper(*_args, &_block)
      @bps = Set.new
    end

    def bp(addr)
      new_bp = internal_bp_create(addr)
      @bps.add new_bp
      new_bp
    end

    def bp_disable(bp)
      if @bps.include?(bp)
        internal_bp_delete(bp)
        bp.internal_representation = nil
        bp.enabled = false
      else
        fail 'not a known breakpoint'
      end
    end

    def bp_disable_at(address)
      bps = @bps.select { |bp| bp.address == address }
      bps.each { |bp| bp_disable(bp) }
    end

    def bp_enable(bp)
      if @bps.include?(bp)
        if bp.internal_representation.nil?
          new_bp = internal_bp_create(bp.addr)
          bp.internal_representation = new_bp.internal_representation
          bp.enable = true
        end
      else
        fail 'not a known breakpoint'
      end
    end

    def bp_list
      list = internal_bp_list
      new_list = list.map do |new_bp|
        old_bp = @bps.find { |old| old.internal_representation == new_bp.internal_representation }
        next old_bp if old_bp
        next new_bp
      end
      @bps = new_list + @bps.select { |bp| !bp.enabled }
      @bps
    end
  end
end
