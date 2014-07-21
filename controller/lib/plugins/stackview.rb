# encoding: utf-8

require_relative 'laneview.rb'
require_relative '../gui/lane.rb'
require_relative '../gui/stack_lane.rb'

silence_warnings do
  require 'json'
  require 'English'
  require 'pp'
end

module Schem
  class StackViewPlugin < LaneViewPlugin
    attr_accessor :byte_width

    def initialize(*args)
      super(*args)
      @lanes = [
        AddressLane.new(self),
        StackLane.new(self),
      ]
      @css_class = 'lv-stack'
      @byte_width = srv.obj.word_width / 8
      @last_address_ranges = (0...20).map { |i| (i * @byte_width...(i + 1) * @byte_width) }
      @follow_expression = 'stack'
    end

    def get_address_ranges(address, lines, lines_before)
      address_ranges = (0...lines).map do |i|
        start = address + (i - lines_before) * @byte_width
        (start...start + @byte_width)
      end
      address_ranges
    end
  end
end

# If you would like to run the plugin uncomment the next line
register_plugin(Schem::StackViewPlugin)
