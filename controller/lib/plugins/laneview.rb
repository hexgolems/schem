# encoding: utf-8

require_relative './plugin.rb'
require_relative '../gui/lane.rb'

silence_warnings do
  require 'json'
  require 'English'
  require 'pp'
end

module Schem
  class LaneViewPlugin < Plugin

    def initialize(*args)
      super(*args)
      @lanes = [] #add you lanes here
      @css_class ="lv-lane"
      @last_address_ranges = [] #(0...20).map{|i| (i*@byte_width...(i+1)*@byte_width)} or whatever you want
      @last_rendering = nil
      @follow_expression = nil
    end

    def follow_and_update()
      return _send_updates unless @follow_expression
      addr = nil
      begin
        addr = srv.expr_eval.evaluate(@follow_expression) rescue nil
      rescue e
        Log.dbg("lanview:follow", "exception in follow expression"+Log.trace(e))
      end
      if addr
        goto(addr)
      else
        send_updated()
      end
    end

    def get_data(address, lines, lines_before, offset_data)

      address_ranges = get_address_ranges(address, lines, lines_before)

      @last_address_ranges = address_ranges
      rendering = get_lane_values(address_ranges)
      return nil if rendering == @last_rendering
      @last_rendering = rendering
      res = {
        type: 'update',
        low_address: address_ranges.first.min,
        high_address: address_ranges.last.min,
        lanes: rendering,
        offset_data: offset_data
      }
      return res
    end

    def get_lane_values(address_ranges)
      res = ""
      sep = "<td class='lv-lane-sep'/>"
      address_ranges.each do |line_range|
        line = @lanes.map { |lane| lane.render_line(line_range) }.join(sep)
        res += "<tr>#{line}</tr>"
      end
      return "<table class='lv-content-table #{@css_class}-table'><colgroup> #{get_lane_colgroups} </colgroup><tbody>#{res}</tbody></table>"
    end

    def get_lane_colgroups
      @lanes.map{|lane| lane.render_colgroup}.join(" ")
    end

    def send_available_actions
      actions_per_lane = @lanes.map do |lane|
          actions = lane.get_available_actions
          actions.map{|a| a && { icon: a[:icon], label: a[:label] } }
        end
      @socket.write(JSON.dump({type: 'actions', actions: actions_per_lane}))
    end

    def send_updated()
        return if !@last_address_ranges || @last_address_ranges.length == 0
        rendering = get_lane_values(@last_address_ranges)
        return if rendering == @last_rendering
        @last_rendering = rendering
        res = {
          type: 'update',
          low_address: @last_address_ranges.first.min,
          high_address: @last_address_ranges.last.min,
          lanes: rendering,
          offset_data: {type: 'delta'}
        }
        @socket.write(JSON.dump(res))
    end

    def handle_data_request(req)
      # addr
      assert { req['address'] != nil}
      addr = req['address'].to_gdbi
      return unless addr
      # lines_before address
      lines_before = req['lines_before'].to_i
      # all in all we need #length many lines
      lines = req['length'].to_i
      offset_data = req['offset_data'] #this field needs to be piped through into the response for the frontend
      data = get_data(addr, lines, lines_before, offset_data)
      @socket.write(JSON.dump(data)) if data
    end

    def goto(address, lines_before=0, origin = nil)
        @goto_stack.push(origin) if origin
        handle_data_request({
          'address' => address,
          'lines_before' => lines_before,
          'length' => @last_address_ranges.length,
          'offset_data' => {type: 'fixed', offset: 0}
          })
    end

    def handle_context_action(req)
      lane_index = req['lane']
      lane = @lanes[lane_index]
      selected = (req['selection_range']['start'].to_i(16)..req['selection_range']['end'].to_i(16))
      clicked = (req['item_range']['start'].to_i(16)..req['item_range']['end'].to_i(16))
      action = req['action']
      lane.perform_action(action,clicked,selected)
    end

    def wait_for_requests_loop
      loop do
        line = @socket.read()
        begin
          req = JSON.parse(line)
          case req['type']
          when "req" then handle_data_request(req)
          when "action" then handle_context_action(req)
          else raise "unknown request #{req.inspect}"
          end
        rescue => e
          Schem::Log.error("plugins:memview:exception",Schem::Log.trace(e))
        end
      end
    end

    def web_run(socket)
      @socket = socket
      assert {@socket != nil}

      send_available_actions
      in_thread do
        wait_for_requests_loop
      end

      wait_for_updates_loop
    end

    def wait_for_updates_loop()
      loop do
        follow_and_update()
        wait_for(srv.on_stop, srv.mem)
      end
    end

    def stop
      @socket.close
    end
  end
end
