# encoding: utf-8
require_relative './plugin.rb'
require 'json'

class ButtonsViewPlugin < Schem::Plugin

  def request(line)
    begin
      case line
      when "play"  then srv.dbg.continue
      when "stepi" then srv.dbg.step_into
      when "stepo" then srv.dbg.step_over
      when "restart" then srv.dbg.restart
      else raise "unknown instruction #{line}"
      end
    rescue
      Schem::Log.error("plugins:buttonsview:exception","in parsing #{line}\n#{Schem::Log.trace}")
    end
  end

  def web_run(socket)
    @socket = socket
    @socket.onclose { puts "Connection closed" }
    @socket.onmessage { |msg| request(msg) }
  end

  def stop
    @socket.close
  end
end
# If you would like to run the plugin uncomment the next line
register_plugin(ButtonsViewPlugin)
