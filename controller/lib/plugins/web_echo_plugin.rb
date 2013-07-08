# encoding: utf-8
require_relative './plugin.rb'

class EchoWebPlugin < Schem::Plugin

  def web_run(socket)
    @socket = socket
    puts 'SPAWNED A WEBPLUGIN YEAY'
    loop do
      line = socket.read()
      puts line.inspect
      socket.write(line.inspect)
    end
  end

  def stop
    puts 'STOPED A WEBPLUING OOOOHHHH'
    @socket.close
  end
end
# If you would like to run the plugin uncomment the next line
register_plugin(EchoWebPlugin)
