# encoding: utf-8
require_relative './gdb_wrapper.rb'
require_relative './debugger_api.rb'
require 'pry'
require 'pp'
require 'wrong'

include Wrong

class DebuggerModuleTest
  attr_accessor :debugger
  include Schem::DebuggerApi
  def initialize(debugger)
    @debugger = debugger
  end
end


  def disasm(addr, lines_before, lines,d)
    res_before = disasm_before(addr, lines_before,d) if lines_before != 0
    res_after = disasm_after(addr, lines-lines_before,d)
    return res_before + res_after
  end

  def disasm_before(addr, lines,d)
      addr_before, res = addr, []
      loop do
        addr_before = addr - (lines *3)
        res = d.disasm_range(addr_before, addr)
        break res.length >= lines+10 # TODO maybe change the +10 offset
      end
      return res[0..lines-1] #TODO
  end

  def disasm_after(addr, lines, d)
    addr_end, res = addr, []
    puts addr_end.inspect
    puts res.inspect
    loop do
      addr_end = addr_end + (lines * 3)
      res = d.disasm_range(addr, addr_end)
      puts res.inspect
      break res.length >= lines
    end
      return res[0..lines-1] # TODO
  end

# wrapper = Schem::GDBWrapper.new('../../run/debugee', '', true)
debugger = Schem::GDBWrapper.new('../../run/debugee_with_debug_info', '', true)
#debugger = Schem::GDBWrapper.new('ls', '', true)

d = DebuggerModuleTest.new(debugger)
assert { d.read_int8(0x60_1040) == -100 }
assert { d.read_int16(0x60_1042) == -1000 }
assert { d.read_int32(0x60_1044) == -1_000_000 }
assert { d.read_int64(0x60_1048) == -1_000_000_000 }
assert { d.read_uint8(0x60_1050)  == 0xff }
assert { d.read_uint16(0x60_1052) == 0xffff }
assert { d.read_uint32('&uint32') == 0xffff_ffff }
assert { d.read_uint64(0x60_1058) == 0xffff_ffff_ffff_ffff }

d.bp_add('main')
d.breakpoints
d.bp_del(d.breakpoints['1'])
d.breakpoints
d.bp_add('main')
d.breakpoints
d.bp_disable(d.breakpoints['2'])
d.breakpoints
d.bp_enable(d.breakpoints['2'])
d.breakpoints
d.bp_addh('do_something')
d.breakpoints
d.bp_addt('some_loop')
d.breakpoints
d.watch_add('uint8')
d.breakpoints
d.watch_addr('uint16')
d.breakpoints
d.watch_adda('uint32')
d.breakpoints
d.watch_del(d.breakpoints['6'])
d.breakpoints
d.run
puts d.display_register_names
puts d.display_registers
d.continue
puts d.display_registers
puts d.display_changed_registers
binding.pry

# debugger_api.bp_add("some_loop")
# pp debugger_api.bp_add("main")
