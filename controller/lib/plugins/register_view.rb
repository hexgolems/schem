# encoding: utf-8
require_relative './plugin.rb'
require 'json'
require 'wrong'

class RegisterViewPlugin < Schem::Plugin
  include Wrong
  def get_data
      @registers = update_register_values
      return {type: 'update', data: @registers}
  end

  def get_register_names
    register_names = display_register_names
    relevant_registers = register_names[0..7]+register_names[16..17]+register_names[110..117]
    return relevant_registers
  end

  def get_register_values
    registers = display_registers "0 1 2 3 4 5 6 7 16 110 111 112 113 114 115 116 117"
    register_values = registers.each_with_index.inject([]){|s,(e,i)| s[i] = e["value"]; s}
    return register_values
  end

  def update_register_values
    register_values = get_register_values
    return Hash[@registers_as_array.zip register_values]
  end

  def gdb_hook(string)
      puts 'register view received: '+string
      if string =~ /stopped/
        puts 'sending updated registers'
        data = get_data
        puts 'register data: ' + data.inspect
        @socket.write(JSON.dump(data))
      end
  end

  def web_run(socket)
    begin
    @registers_as_array = get_register_names
    @registers = update_register_values
    @socket = socket
    assert {@socket != nil}

    act = Actor.current
    #@debugger.register_type_hook('console','exec','log') do |msg|
    @debugger.register_type_hook('exec') do |msg|
      act.async.gdb_hook(msg.value)
    end

    loop do
      line = socket.read()
      puts line.inspect
      socket.write(JSON.dump(get_data()))
    end
    rescue
      Schem::Log.error("plugins:registerview:parsing:exception",Schem::Log.trace)
    end
  end

  def stop
    @socket.close
  end
end
# If you would like to run the plugin uncomment the next line
register_plugin(RegisterViewPlugin)
