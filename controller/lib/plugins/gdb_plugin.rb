# encoding: utf-8
require_relative './plugin.rb'
require 'redis'
require 'pp'

class GDBPlugin < Schem::Plugin
    def initialize(mgr, ctrl)
        super(mgr,ctrl)
        init_debugger_api(@debugger)
        redis_connection('gdb_in')
        redis_connection('gdb_out')
    end

    # this function is used as a callback in auto_run_start and will write a string to the channel `gdb_out`
    def gdb_hook(string)
        redis_connection('gbd_out').publish(:gdb_out, string)
    end

    def handle_message(channel, message)
        redis_connection('gdb_in').unsubscribe if message == 'exit'
        res = cli_exec(message)
        redis_connection('gdb_out').publish(:gdb_out, res.inspect)
    end

    def  listen_subscription_handler(on)
      on.subscribe do |channel, subscriptions|
      end

      on.message do |channel, message|
        handle_message(channel, message)
      end

      on.unsubscribe do |channel, subscriptions|
      end
    end

    def auto_run

        @debugger.register_type_hook('console','exec','log') do |msg|
          self.gdb_hook(msg.value)
        end

        begin
          redis_connection('gdb_in').subscribe(:gdb_in) do |on|
            listen_subscription_handler(on)
          end
        rescue ::Redis::BaseConnectionError => error
          puts "#{error}, retrying in 1s"
          sleep 1
          retry
        end
    end


end

#register_plugin(GDBPlugin)
