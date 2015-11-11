# encoding: utf-8
require_relative './dependencies.rb'
require_relative './include.rb'
silence_warnings do
  require 'pry'
end

$VERBOSE = true
require_relative './logger/logger.rb'
require_relative './config.rb'
require_relative './commandline_options.rb'
require_relative './webserver/emserver.rb'
require_relative './plugins/manager.rb'
require_relative './services/manager.rb'

Thread.abort_on_exception = true

module Schem
  class DBGController
    attr_reader :debugger, :plugin_manager, :service_manager, :path_to_exe

    def s
      stepi
    end

    def stepi
      debugger.send_cli_string('stepi')
    end

    def bmain
      debugger.send_cli_string('b main')
    end

    def c
      debugger.send_cli_string('c')
    end

    def inspect
      to_s
    end

    def load_backend(backend)
      if backend == 'gdb'
        require_relative './backend_connections/gdb_wrapper.rb'
        require_relative './backend_connections/gdb_api.rb'
      elsif backend == 'pin'
        require_relative './backend_connections/pin_wrapper.rb'
        require_relative './backend_connections/pin_api.rb'
      else
        fail 'unsupported backend'
      end
    end

    # rubocop:disable MethodLength
    def start
      @options = parse_arguments
      load_backend(@options.backend)
      DbgConfig.load
      Schem.init_logger
      spawn

      at_exit do
        stop
      end

      srv = service_manager.srv
      binding.dbg
      sleep(100) loop do

      exit
    end
    # rubocop:enable MethodLength

    def spawn
      @path_to_exe = File.expand_path('../run/debugee_with_debug_info')
      @debugger = spawn_debugger
      @plugin_manager = load_plugins
      @service_manager = load_services
      @webserver = spawn_web
    end

    def spawn_debugger
      if @options.backend == 'gdb'
        return Schem::GDBWrapper.new(@path_to_exe, '', true)
      elsif @options.backend == 'pin'
        return Schem::PINWrapper.new(@path_to_exe, '', true)
      elsif
        fail 'Backend not supported'
      end
    end

    def spawn_web
      server = Schem::WebServer.new(@plugin_manager)
      server
    end

    def load_plugins
      @plugin_manager = PluginManager.new
      @plugin_manager.load(self)
      @plugin_manager.run_all_auto
      @plugin_manager
    end

    def load_services
      @service_manager = ServiceManager.new
      @service_manager.load(self)
      @debugger.on_stop { @service_manager.on_stop }
      @debugger.on_execute { @service_manager.on_execute }
      @debugger.on_quit { @service_manager.on_quit }
      @service_manager
    end

    def stop
      shutdown_plugins
      shutdown_debugger
      exit
    end

    def shutdown_plugins
      @plugin_manager.shutdown
    end

    def shutdown_debugger
    end
  end
end

Pry.rescue_in_pry do
  ctrl = Schem::DBGController.new
  ctrl.start
end
