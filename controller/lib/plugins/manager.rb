# encoding: utf-8
require_relative '../include.rb'


silence_warnings do
  require 'pp'
  require 'socket'
  require 'monitor'
end


# @param [Class] pclass register this Class as a plugin
# This function adds the given Class to the list of registered plugins in the
# current specified plugin manager
def register_plugin(pclass)
  raise "expected a class not #{pclass.class}" unless pclass.class == Class
# rubocop:disable AvoidGlobalVars
  $registering_plugin_manager.register_plugin(pclass)
# rubocop:enable AvoidGlobalVars
end

module Schem

  class PluginManager
    include MonitorMixin
    def initialize(*args)
      super
      @plugins = Set.new
      @plugin_instances = Set.new
      @controller = nil
    end

    # this function will reload all plugins
    # @param [Schem::DBGControll] controller the current controller
    def load(controller)
      surround("pluginmanager","loading plugins") do
        @controller = controller
        # rubocop:disable AvoidGlobalVars
        $registering_plugin_manager = self
        load_files()
        $registering_plugin_manager = nil
        # rubocop:enable AvoidGlobalVars
     end
    end

    # this function will go through the plugin folder and load all ruby files recursively
    def load_files(path = File.dirname(__FILE__))
      Dir.glob(path+"/**/*.rb").each do |file|
        load_one_file(file) if file != __FILE__ && File.basename(file) != "plugin.rb"
      end
    end

    # this function will Kernel.require the given file
    def load_one_file(path)
      Kernel.require(path)
    end

    # this function will register the given plugin in this managers list of plugins
    # will be used  by the global `register_plugin`
    # @param [Class] plugin the plugin
    def register_plugin(plugin)
      Log.info('plugins',"registered #{plugin}")
      synchronize do
        @plugins << plugin
      end
    end

    def register_plugin_instance(instance)
      synchronize do
        @plugin_instances << instance
      end
    end


    # removes the given instance if it is currently managed by the plugin manager
    def remove_instance(instance)
      synchronize do
        @plugin_instances.delete(instance)
      end
    end

    # will return a duplicat of the internal list of known plugins
    def list_known_plugins
      synchronize do
        @plugins.dup.to_a
      end
    end

    # will return a duplicat of the internal list of instanciated plugins
    def list_plugin_instances
      synchronize do
        @plugin_instances.dup.to_a
      end
    end


    # this function creates a set of instances for all plugins which match block
    def create_all_where(&block)
      synchronize do
        Set.new(@plugins.select(&block).map { |pclass| pclass.new(self, @controller) })
      end
    end

    # this function creates one instance per plugin in the plugin list that
    # hast `auto_run.*` methods and run all those methods
    def run_all_auto
      synchronize do
        surround("pluginmanager","running auto_runs") do
          plugin_instances = create_all_where(&:auto_run?)
          plugin_instances.each(&:async_auto_run)
          plugin_instances.each{|inst| register_plugin_instance(inst) }
        end
      end
    end

    # finds a plugin by its name, caseinsensitive and by ignoring trailing any "plugin" string
    def find_plugin(name)
      synchronize do
        return @plugins.find do |pclass|
          pclass.to_s.downcase.gsub(/plugin\Z/, '').gsub("schem::","") == name.downcase.gsub(/plugin\Z/,'')
        end
      end
    end


    # try to find a plugin by the given name and instantiate it / run its web_run method
    # returns true if a pluign was found, false otherwise
    def run_web(name, sock)
      synchronize do
        plugin = find_plugin(name)
        if plugin && plugin.web_run?
          inst = plugin.new(self, @controller)
          register_plugin_instance(inst)
          inst.async_web_run(sock)
          return true
        end
        return false
      end
    end

    # this function will call shutdown on every plugin instance
    def shutdown
      synchronize do
        @plugin_instances.each(&:shutdown)
      end
    end

  end
end
