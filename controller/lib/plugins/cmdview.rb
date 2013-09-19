# encoding: utf-8
require_relative './plugin.rb'
require 'json'

class CMDViewPlugin < Schem::Plugin

  def send_message(string)
    @socket.send( JSON.dump({type: 'update', data: string}) )
  end

  def request(line)
    line = socket.read()
    begin
      req = JSON.parse(line)
      srv.dbg.send_cli_string(req["line"])
      #@redis.publish("gdb_in",req["line"])
      send_message(">"+req["line"])
    rescue
      Schem::Log.error("plugins:cmd_view:exception","in parsing #{line}\n#{Schem::Log.trace}")
    end
  end

  def web_run(socket)
    @socket = socket
    @socket.onclose { puts "Connection closed" }
    @socket.onmessage { |msg| request(msg) }
    @redis = redis_connection('gdb_cmds')

    handler = Schem::ThreadedEventHandler.new do |msg|
        self.send_message(msg.value.gsub('\n',''))
    end

    srv.dbg.get_internal_debugger_object.register_event_handler('console','log',handler)

  end

  def stop
    @socket.close
  end
end
# If you would like to run the plugin uncomment the next line
register_plugin(CMDViewPlugin)
