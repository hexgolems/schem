# encoding: utf-8
silence_warnings do
  require 'pry'
  require 'thread/delay'
  require 'thread/channel'
  require 'set'
end

require_relative './service.rb'

# @param [Symbol] name, the name under which this
# @param [Service] service register this object as a service
# This function adds the given object to the list of registered services in the
# current specified service manager
def register_service(name, service)
  # rubocop:disable AvoidGlobalVars
  $registering_service_manager.register(name, service)
  # rubocop:enable AvoidGlobalVars
end

module Schem
  # TODO document me
  class ServiceFinder < BasicObject
    def initialize(services)
      @services = services
    end

    def method_missing(name, *args, &block)
      super unless @services.include? name || args.length != 0
      service = @services[name]
      ::Kernel.raise 'Circular dependency' if service.is_initialized == :working
      if service.is_initialized != :done
        service.is_initialized = :working
        service.init_callback if service.respond_to?(:init_callback)
        service.is_initialized = :done
      end
      service
    end

    def respond_to_missing?(name, include_private = false)
      @services.include?(name) || super
    end
  end
  # TODO document me
  class ServiceManager
    attr_reader :service_finder
    attr_accessor :services

    def initialize
      @services = {}
      @objs_to_names = {}
      @service_finder = ServiceFinder.new(@services)
    end

    # TODO maybe just a reader? And not a method
    def srv
      @service_finder
    end

    def on_stop
      @services.each_value do |serv|
        serv.stop_callback if serv.respond_to? :stop_callback
      end
    end

    def on_execute
      @services.each_value do |serv|
        serv.execute_callback if serv.respond_to? :execute_callback
      end
    end

    def on_quit
      @services.each_value do |serv|
        serv.quit_callback if serv.respond_to? :quit_callback
      end
    end

    def load(controller)
      surround('servicemanager', 'loading services') do
        @controller = controller
        $registering_service_manager = self
        files = Dir.glob("#{File.dirname(__FILE__)}/**/*.rb")
        files.each do |file|
          Kernel.load(file, false) if file != __FILE__ && File.basename(file) != 'service.rb'
        end
        $registering_service_manager = nil
      end

      surround('servicemanager', 'initializing services') do
        @services.each_value do |service|
          if service.is_initialized != :done
            service.is_initialized = :working
            service.init_callback if service.respond_to?(:init_callback)
            service.is_initialized = :done
          end
        end
      end
    end

    def register(name, klass)
      assert { name.is_a? Symbol }
      assert { klass.is_a? Class }
      if @services.include? name
        Log.info('services:register', "overwrite service #{name} (old: #{@services[name]}, new: #{klass})")
      end
      Log.info('services:register', "registering #{klass.inspect} as #{name.inspect}")
      @services[name] = klass.new(@controller)
      @objs_to_names[@services[name]] = name
    end

    def remove(obj)
      if @objs_to_name.include? obj
        name = @objs_to_name[obj]
        @services.delete name
        @objs_to_name.detel obj
      else
        Log.error('services', "tyring to remove unknonw service #{obj}")
      end
    end

    def [](name)
      if @services.include? name
        return @services[name]
      else
        Log.error('services', "tyring to access unknonw service #{name}")
        return nil
      end
    end

    # TODO maybe just a reader? And not a method
    def list_services
      @services
    end
  end
end
