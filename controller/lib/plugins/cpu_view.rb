# encoding: utf-8
require_relative './plugin.rb'
require 'json'
require 'English'
require 'pp'
require 'wrong'

class CPUViewPlugin < Schem::Plugin

  include Wrong
  def get_data(addr, lines_before, length, offset_data)
    res = { type: 'update' }
    res['data'] = disasm(addr, lines_before, length)
    res['offset_data'] = offset_data
    assert { res['data'].length == length }
    return res
  end

  def disasm(addr, lines_before, lines)
    res_before = []
    res_before = disasm_before(addr, lines_before)  if lines_before != 0
    res_after = disasm_after(addr, lines-lines_before)
    res = (res_before + res_after)
    res = res.each{|x| x["address"] = (x["address"].gsub(/0x0+/,"0x0"))}
  end

  def disasm_before(addr, lines)
      addr_before, res = addr, []
      loop do
        addr_before = addr_before - (lines * 3)
        res = disasm_range(addr_before, addr)
        return (0..lines-1).map{|i| {"address" => (addr+i).to_gdbs(16), "inst" => "(BAD)"}} unless res
        break if res.length > lines
      end
      Schem::Log.dbg("plugins:cpuview", "address: #{addr}\n lines: #{lines}\n result:\n#{res[(res.length-lines)..-1]}")
      return res[(res.length-lines)..-1]
  end

  def disasm_after(addr, lines)
    addr_end, res = addr, []
    loop do
      addr_end = addr_end + (lines * 3)
      res = disasm_range(addr, addr_end)
      return (0..lines-1).map{|i| {"address" => (addr+i).to_gdbs(16), "inst" => "(BAD)"}} unless res
      break if res.length > lines
    end
      Schem::Log.dbg("plugins:cpuview", "address: #{addr}\n lines: #{lines}\n result:\n#{res[(res.length-lines)..-1]}")
      return res[0..lines-1] # TODO
  end

    def initialize(mgr, ctrl)
      super(mgr,ctrl)
      init_debugger_api(@debugger)
  end

  def gdb_hook(string)
      if string =~ /stopped/
        rip = display_registers(16).first['value'].to_i(16)
        data = get_data(rip, 0, 100, {type: 'fixed', offset: 0}) # TODO maybe change from 30 to 100?
        @socket.write(JSON.dump(data))
      end
  end

  def web_run(socket)
    @socket = socket
    assert {@socket != nil}
    act = Actor.current

    @debugger.register_type_hook('exec') do |msg|
      act.async.gdb_hook(msg.value)
    end

    # This will display the right code when started
    gdb_hook("stopped")     

    loop do
      line = socket.read()
      begin
        req = JSON.parse(line)
        puts '*'*80
        puts req.inspect
        puts '*'*80
        # addr
        assert { req['address'] != nil}
        addr = req['address'].to_gdbi
        # lines_before address
        lines_before = req['lines_before']
        # all in all we need #length many lines
        length = req['length']
        offset_data = req['offset_data']
        data = get_data(addr, lines_before, length, offset_data)
        @socket.write(JSON.dump(data))
      rescue
        Schem::Log.error("plugins:cpuview:exception",Schem::Log.trace)
      end
    end
  end

  def stop
    @socket.close
  end
end
# If you would like to run the plugin uncomment the next line
register_plugin(CPUViewPlugin)
