# encoding: utf-8
require 'pp'
require 'socket'
require 'redis'
require 'celluloid/io'
require 'celluloid/redis'
require_relative '../gdb_connection/debugger_api.rb'
require 'pry'

# @param [Class] pclass register this Class as a plugin
# This function adds the given Class to the list of registered plugins in the
# current specified plugin manager
def register_plugin(pclass)
  raise "expected a class not #{pclass.class}" unless pclass.class == Class
# rubocop:disable AvoidGlobalVars
  $registering_plugin_manager.register(pclass)
# rubocop:enable AvoidGlobalVars
end

module Schem

  class PluginManager

    def initialize
      @plugins = []
      @plugin_instances = []
      @controller = nil
    end

    # this function will shutdown & clear the current list of plugins and then reload all plugins
    # @param [Schem::DBGControll] controller the current controller
    def load(controller)
      @controller = controller
      shutdown()
      @plugins = Set.new
      @plugin_instances = Set.new
      reload()
    end

    def is_responding(pluign, timeout = 0.1)
      res = []
      plugin.async.test_async(res)
      sleep(timeout)
      return res[0]
    end

    # this function will go through the plugin folder and load all ruby files recursively
    def reload
      Dir.glob("#{File.dirname(__FILE__)}/**/*.rb").each do |file|
        Kernel.load(file, false) if file != __FILE__
      end
    end

    # this function will register the given plugin in this managers list of plugins
    # will be used  by the global `register_plugin`
    # @param [Class] plugin the plugin
    def register(plugin)
      Log.info('plugins',"registered #{plugin}")
      @plugins << plugin
    end

    def remove(instance)
      @plugin_instances.delete(instance)
    end

    # this function creates one instance per plugin in the plugin list that
    # hast `auto_run.*` methods and run all those methods
    def run_auto
      @plugin_instances = Set.new(@plugins.select(&:is_auto_run?).map { |pclass| pclass.new(self, @controller) })
      @plugin_instances.each(&:async_auto_run)
    end

    def run_web(name, sock)
      plugin_name_list = @plugins.map { |pclass| pclass.to_s.downcase.gsub(/plugin\Z/, '') }
      plugin = @plugins.find { |pclass| pclass.to_s.downcase.gsub(/plugin\Z/, '') == name }
      if plugin
        inst =  plugin.new(self, @controller)
        @plugin_instances << inst
        inst.async_web_run(sock)
        return true
      end
      return false
    end

    # this function will call shutdown on every plugin instance
    def shutdown
      plugins = @plugin_instances.select(&:alive?)
      # since plugins deregister themselfs from the manager @plugin_instances will be modified
      # thus we work on a copy of @plugin_instances
      plugins.each(&:terminate)
      sleep 0.2
    end

  end
end
