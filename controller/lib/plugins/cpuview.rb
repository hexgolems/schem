# encoding: utf-8

require_relative 'laneview.rb'
require_relative '../gui/lane.rb'
require_relative '../gui/disassembly_lane.rb'

silence_warnings do
  require 'json'
  require 'English'
  require 'pp'
end

module Schem
  class CpuViewPlugin < LaneViewPlugin
    def initialize(*args)
      super(*args)
      @disasm_lane = DisassemblyLane.new(self)
      @lanes = [
        AddressLane.new(self),
        @disasm_lane
      ]
      @css_class = 'lv-cpu'
      @last_address_ranges = []
      @lines = 30
    end

    def get_address_ranges(address, lines, lines_before)
      @lines = lines
      @last_address_ranges = @disasm_lane.get_address_ranges(address, lines, lines_before)
      @last_address_ranges
    end

    def get_entrypoints
      addresses = %w(main entrypoint).map { |name| srv.tags.by_name(name).map { |t| t.range.min } }
      possible_eps = addresses.flatten.compact.uniq
      possible_eps
    end

    def wait_for_updates_loop
      eps = get_entrypoints
      get_address_ranges(eps.first, @lines, 3) if eps.length > 0
      send_updated
      loop do
        ip = srv.reg.ip
        if ip
          type = srv.types.get_newest_type_at(ip)
          srv.disasm_updater.disasm(ip .. ip + 100) unless type.class == InstructionType && type.range.min == ip
          goto(ip, 3, srv.reg.old_ip)
        end
        wait_for(srv.on_stop, srv.mem)
      end
    end
  end
end

# If you would like to run the plugin uncomment the next line
register_plugin(Schem::CpuViewPlugin)
