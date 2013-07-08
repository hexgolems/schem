# encoding: utf-8
require_relative './plugin.rb'

class HelloWorldPlugin < Schem::Plugin

  def auto_run
    puts 'HELLO WORLD PLUGIN'
  end

  def stop
    puts 'GOOD BYE CRUEL WORLD'
  end
end

# If you would like to run the plugin uncomment the next line
register_plugin(HelloWorldPlugin)
