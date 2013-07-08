# encoding: utf-8
require_relative './plugin.rb'
require 'json'

class StructViewPlugin < Schem::Plugin

  def get_data
    { type: 'update', data: { eax: 12345, ebx: Time.now.to_i, ecx: 456 } }
  end

  def web_run(socket)
    @socket = socket
    puts 'SPAWNED A StructViewPLUGIN YEAY'

    loop do
      line = socket.read()
      puts line.inspect
      socket.write(JSON.dump(get_data()))
    end
  end

  def stop
    puts 'STOPED A StructView OOOOHHHH'
    @socket.close
  end
end
# If you would like to run the plugin uncomment the next line
register_plugin(StructViewPlugin)
