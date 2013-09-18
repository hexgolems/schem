# encoding: utf-8
silence_warnings do
  require 'pp'
  require 'socket'
  require 'redis'
  require 'thread/delay'
  require 'thread/channel'
  require 'set'
end

require_relative '../backend_connections/gdb_api.rb'
require_relative './manager.rb'
require_relative '../services/manager.rb'

module Schem

  class PluginShouldStop < Exception
  end

# subclass this class to create your own plugin
  class Plugin
    class Thread
      def initialize
        raise "please use #in_thread to create new threads in plugins"
      end
    end

    # TODO make this modular

    attr_accessor :controller, :redis, :debugger, :goto_stack

    def srv
      @controller.service_manager.service_finder
    end

    # @param [Schem::DBGController] ctrl the controller this plugin will run under
    # @param [Schem::PluginManager] mgr the manager that manges this plugin
    def initialize(mgr, ctrl)
      # TODO test this
      @controller = ctrl
      @manager = mgr
      @redis_connections = {}
      @threads = Set.new
      @update_channel = ::Thread.channel
      @watching = nil
      @goto_stack = []
    end

    def ensure_consistency(reason,&block)
      ::Thread.current[:is_inside_ensure_consistency] = true
      begin
        loop do
          old_invalidation_counters = reason.services_watching.map{|service| service.invalidation_counter}
          block.call()
          new_invalidation_counters = reason.services_watching.map{|service| service.invalidation_counter}
          break if old_invalidation_counters == new_invalidation_counters
        end
      ensure
        ::Thread.current[:is_inside_ensure_consistency] = false
      end
    end

    def wait_for(*services)
      if @watching
        not_watching_anymore = @watching - services
        not_watching_anymore.each { |service| service.deregister_waiting(@update_channel) }
      end
      services.each{|service| service.register_waiting(@update_channel) }
      @watching = services
      reason = @update_channel.receive
      reason.services_watching = services
      return reason
    end

    # returns true if this plugin has an `auto_run` method
    def self.auto_run?
      return self.method_defined? :auto_run
    end

    # returns true if this plugin has a `web_run` method
    def self.web_run?
      return self.method_defined? :web_run
    end

    # returns true if this plugin has a `manual_run.*` methods
    def self.manual_run?
      return self.method_defined? :manual_run
    end

    #Creates a new thread that is associated with this plugin
    #makes sure that all exceptions are cought nad logged properly
    #if you want to use a thread in your plugin, make sure to use this functions
    #This will also make sure that the thread will be killed with the plugin
    def in_thread(task_desc = "in_thread",&block)
      t = ::Thread.new do
        if DbgConfig.controller.debug_with_pry
          Pry.rescue_in_pry do
            block.call()
          end
        else
          begin
            block.call()
          rescue PluginShouldStop
          rescue => e
            err = "Excpetion in #{task_desc}: #{Log.trace(e)}"
            path = "plugins:crashed:#{self.class}"
            Log.error(path, err)
          end
        end
      end
      @threads.add t
      return t
    end

    #this function will perform a send to self but in a new thread
    def async_send(method,*args, &block)
      method_call = "async call to #{self.to_s}." #TODO WHY OH WHY
      method_call += "#{method}(#{args.map(&:to_s).join(" , ")},"
      method_call += "  &#{block.inspect})"
      in_thread(method_call) do
        self.send(method,*args,&block)
      end
    end

    # this method asnychroniusly calls the function with the name `auto_run.*`
    # this method will be called upon loading the plugin
    def async_auto_run
      async_send(:auto_run)
    end

    # this method asnychroniusly calls web_run
    # it will pass the given websocket to web_run
    # this method will be called upon a a websocket request by the frontend
    def async_web_run(socket)
      async_send(:web_run,socket)
    end

    # this method asnychroniusly calls manual_run
    # it will pass the given arguments to manual_run
    # this method must be called manualy (e.G. as an response to the user clicking something)
    def async_manual_run(*args)
      async_send(:web_run,*args)
    end

    # This function will call `self.stop` if the sub class defines this method upon
    # unloading this plugin. Define `stop` in your subclass if you need to free ressources etc.
    # all threads recieve a PluginShouldStop exception. They may handle this
    # exception themselfs if some cleanup is to be performec
    def shutdown
      Log.info("plugins:closed","stoped #{self.class}")
      begin
        stop if respond_to? :stop
        @manager.remove_instance(self)
        @redis_connections.each_value do |redis|
          redis.quit rescue nil # TODO find out why this raises exceptions
        end
        @threads.each{ |t| t.raise(PluginShouldStop) }
      rescue
        Log.error("plugins:closed:execption",Log.trace)
      end
    end

    # This function will create a new Redis connection for the plugin to use.
    # The connections will be closed on terination by the plugin, so no need to do it yourself
    def redis_connection(name)
        return @redis_connections[name] if @redis_connections.include? name
        res = @controller.new_redis_connection
        @redis_connections[name] = res
        return res
    end

  end
end
