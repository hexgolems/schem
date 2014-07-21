# encoding: utf-8
require_relative './plugin.rb'
require 'json'

module Schem
  class StructViewPlugin < Plugin
    def self.action(name, icon = nil, &block)
      @actions ||= {}
      @actions[name] = [block, icon]
    end

    def self.actions
      @actions ||= {}
    end

    def self.depends_on(*args)
      @dependencies = args
    end

    def self.dependencies
      @dependencies ||= []
    end

    def perform_action(action, *args)
      block, icon = self.class.actions[action]
      instance_exec(*args, &block)
    end

    def wait
      wait_for(*self.class.dependencies.map { |name| srv.__send__(name) })
    end

    def get_data
      { type: 'update', data: some_json_object }
      # => you should implement this
    end

    def handle_context_action(req)
      name = req['name']
      action = req['action']
      perform_action(action, name)
    end

    def update!
      @socket.send(JSON.dump(get_data))
    end

    def wait_for_updates_loop
      loop do
        update!
        wait
      end
    end

    def request(line)
      req = JSON.parse(line)
      case req['type']
      when 'action' then
        handle_context_action(req)
      else fail "unknown request #{req.inspect}"
      end
    rescue => e
      Schem::Log.error('plugins:structview:exception', Schem::Log.trace(e))
    end

    def send_available_actions
      actions = self.class.actions.each_pair.map { |name, (_, icon)| { icon: icon, label: name } }
      @socket.send(JSON.dump(type: 'actions', actions: actions))
    end

    def web_run(socket)
      @socket = socket
      @socket.onclose { puts 'Connection closed' }
      @socket.onmessage { |msg| request(msg) }
      assert { !@socket.nil? }
      send_available_actions
      wait_for_updates_loop
      rescue => e
        Schem::Log.error("plugins:#{self.class.to_s.downcase}", Schem::Log.trace(e))
    end

    def stop
      @socket.close
    end
  end
end
