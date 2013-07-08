# encoding: utf-8
# rubocop: disable StringLiterals
# require './gdb_connection/wrapper.rb'
# require './plugin.rb'
# require 'pry'
# require 'pp'

wrapper = Schem::GDBWrapper.new('ls', '', true)
p1 = Schem::Plugin.new(wrapper)
p1 = Schem::Plugin.new(wrapper)
sleep 5
exit

# wrapper = Schem::GDBWrapper.new("ls")
pp wrapper.send_mi_string("-data-disassemble -s $pc -e \"$pc+1\" -- 0")
sleep 1
# rubocop: disable StringLiterals
