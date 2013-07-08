# encoding: utf-8

require 'redis'

require_relative './logger/logger.rb'
require_relative './config.rb'
require_relative './commandline_options.rb'
require_relative './webserver/webserver.rb'
require_relative './plugins/plugin.rb'
require_relative './gdb_connection/gdb_wrapper.rb'

Thread.abort_on_exception = true
Celluloid.exception_handler { |ex| Schem::Log.critical("celluloid:excpetion",Schem::Log.trace()) }
#Celluloid.logger = nil

module Schem

  class DBGController
    attr_accessor :debugger
# rubocop:disable MethodLength
    def start
      puts 'parse cmdlines'
      parse_arguments()
      puts 'load config'
      DbgConfig.load()
      Schem.init_logger()
      puts 'spawning'
      spawn

      puts 'testwrites'
      test_write()
      @redis.save()
      @meh = 0

      at_exit do
        stop()
      end

      puts 'running in a fucking loop'
      loop do
        @meh += 1
        exit if @meh == 1000
        sleep 1
      end
    end
# rubocop:enable MethodLength

    def spawn
      # @path_to_exe = File.expand_path('/bin/ls')
      @path_to_exe = File.expand_path('../run/debugee_with_debug_info')
      @redis_pipe, @redis = spawn_redis()
      @debugger = spawn_debugger()
      @plugin_manager = load_plugins()
      @webserver = spawn_web(@plugin_manager)
    end

    def test_write
      @redis['foo'] = 'bar'
    end

    def get_redis_config
      version = `redis-server -v`
      case version
      when /2.2.12/ then return 'redis.2.2.12.conf'
      when /2.6.7/ then return 'redis.2.6.7.conf'
      end
      return nil
    end

    def new_redis_connection
        path = File.expand_path(File.join(DbgConfig.redis.sock_path , 'redis.sock'))
        return Redis.new( path: path, driver: :celluloid )
    end

    def spawn_redis
      version_config = get_redis_config
      puts "Spawning redis-server version: #{version_config}"
      raise "unsuported version #{`redis-server -v`}" unless version_config
      path = File.expand_path(File.join(DbgConfig.redis.config_path, version_config))
      pipe = IO.popen("redis-server #{path}")
      redis = new_redis_connection
      puts redis.inspect
      return pipe, redis
    end

    def spawn_debugger
      puts 'spawn debugger'
      return Schem::GDBWrapper.new(@path_to_exe, '', true)
    end

    def spawn_web(plugin_manager)
      server = Schem::WebServer.new()
      server.plugin_manager = plugin_manager
      return server
    end

    def load_plugins
      puts 'loading plugins'
      @plugin_manager = PluginManager.new
      # rubocop:disable AvoidGlobalVars
      $registering_plugin_manager = @plugin_manager
      # rubocop:enable AvoidGlobalVars
      @plugin_manager.load(self)
      # rubocop:disable AvoidGlobalVars
      $registering_plugin_manager = nil
      # rubocop:enable AvoidGlobalVars
      puts 'spawning plugin coroutines'
      @plugin_manager.run_auto()
      return @plugin_manager
    end

    def stop
      shutdown_plugins()
      Celluloid.shutdown()
      shutdown_redis()
      shutdown_debugger()
      exit
    end

    def shutdown_plugins
      puts 'shutdown plugins'
      @plugin_manager.shutdown()
    end

    def shutdown_redis
      puts 'shutdown redis'
# @redis.save
      @redis.shutdown
#     Process.kill('TERM', @redis_pipe.pid)
#     Process.wait(@redis_pipe.pid)
#     @redis_pipe.close
      puts 'done closing redis pipe'
    end

    def shutdown_debugger
      puts 'shutdown debugger'
    end

  end
end

ctrl = Schem::DBGController.new
ctrl.start()
