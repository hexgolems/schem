# encoding: utf-8
require 'pp'
require 'socket'
require 'redis'
require 'celluloid/io'
require 'celluloid/redis'
require 'wrong'
require_relative '../gdb_connection/debugger_api.rb'
require_relative './manager.rb'

module Schem

# subclass this class to create your own plugin
  class Plugin

    include Wrong
    include Celluloid::IO
    include Schem::DebuggerApi

    attr_accessor :controller, :redis, :debugger
    finalizer :shutdown

    # @param [Schem::DBGController] ctrl the controller this plugin will run under
    # @param [Schem::PluginManager] mgr the manager that manges this plugin
    def initialize(mgr, ctrl)
      # TODO test this
      @controller = ctrl
      @debugger = @controller.debugger
      @manager = mgr
      @redis_connections = {}
      init_debugger_api(@debugger)
    end

    # this method will be called after running the plugin if it doesn't set checker.called = true within 0.1 second
    # the loader will warn
    def async_test(checker)
      checker[0] = true
    end

    # returns true if this plugin has any `auto_run.*` methods
    def self.is_auto_run?
      instance_methods.any? { |name| name =~ /\Aauto_run/ }
    end

    # returns true if this plugin has any `web_run.*` methods
    def self.is_web_run?
      instance_methods.any? { |name| name =~ /\Aweb_run/ }
    end

    # returns true if this plugin has any `manual_run.*` methods
    def self.is_manual_run?
      instance_methods.any? { |name| name =~ /\Amanual_run/ }
    end

    # this method asnychroniusly calls all plugin members with the name `auto_run.*`
    # this method will be called upon loading the plugin
    def async_auto_run
      methods.select { |name| name =~ /\Aauto_run/ }.each do |name|
        async.send name
      end
    end

    # this method asnychroniusly calls all plugin members with the name `web_run.*`.
    # it will pass the given websocket to all `web_run.*` methods as well.
    # this method will be called upon a a websocket request by the frontend
    def async_web_run(socket)
      methods.select { |name| name =~ /\Aweb_run/ }.each do |name|
        async.send(name, socket)
      end
    end

    # this method asnychroniusly calls all plugin members with the name `manual_run.*`.
    # it will pass the given arguments to the `manual_run.*` as well
    # this method must be called manual
    def async_manual_run(args)
      methods.select { |name| name =~ /\Amanual_run/ }.each do |name|
        async.send(name, args)
      end
    end

    # This function will call `self.stop` if the sub class defines this method upon
    # unloading this plugin. Define `stop` in your subclass if you need to free ressources etc.
    def shutdown
      Log.info("plugins:closed","stoped #{self.class}")
      begin
      @manager.remove(self)
      stop if self.respond_to? :stop
      @redis_connections.each_value do |redis|
        redis.quit rescue nil # TODO find out why this raises exceptions
      end
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
