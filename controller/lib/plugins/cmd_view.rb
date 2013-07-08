# encoding: utf-8
require_relative './plugin.rb'
require 'json'

class CMDViewPlugin < Schem::Plugin

  def send_message(string)
    @socket.write( JSON.dump({type: 'update', data: string}) )
  end

    def web_run_listener(sock)
      act = Actor.current

      @debugger.register_type_hook('console') do |msg|
        act.async.send_message(msg.value.gsub('\n',''))
      end

      @debugger.register_type_hook('log') do |msg|
        act.async.send_message(msg.value.gsub('\n',''))
      end

    end

  def web_run(socket)
    @socket = socket
    @redis = redis_connection('gdb_cmds')

    loop do
      line = socket.read()
      begin
        req = JSON.parse(line)
        #TODO SEND SHIT TO GDB
        @redis.publish("gdb_in",req["line"])
        send_message(">"+req["line"])
      rescue
        Schem::Log.error("plugins:cmd_view:exception","in parsing #{line}\n#{Schem::Log.trace}")
      end
    end
  end

  def stop
    @socket.close
  end
end
# If you would like to run the plugin uncomment the next line
register_plugin(CMDViewPlugin)
