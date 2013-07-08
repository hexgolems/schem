# encoding: utf-8
require_relative './gdb_wrapper.rb'
require_relative './breakpoint.rb'

module Schem

  module DebuggerApi
    attr_reader :breakpoints
    def init_debugger_api(debugger)
        @breakpoints = {}
    end

    def bp_list
        @debugger.send_mi_string('-break-list')
    end

    def bp_update(breaklist)
        breaklist.each_pair do |name, bp|
            bpt = Breakpoint.new(bp)
            @breakpoints[bpt.number] = bpt
        end
    end

    def bp_parse
        list = bp_list
        breaklist = list.first.value['BreakpointTable']['body']
        @breakpoints = {}
        return nil if breaklist.is_a?(Array) && breaklist.length == 0
        return bp_update(breaklist) if list.first.content_type == 'done'
        raise "unable to parse breakpoint list! #{list.inspect}"
    end

    def bp_add(addr, mode = '')
        return false if mode != '-t' && mode != '-h' && mode  !=  ''
        num = @debugger.send_mi_string("-break-insert #{mode} #{addr}")
        if num.first.content_type == 'done'
            bp_parse
            return @breakpoints[num.last.value['bkpt']['number']]
        else
            return false
        end
    end

    def bp_addh(addr) # will create a hardware breakpoint
        bp_add(addr, '-h')
    end

    def bp_addt(addr) # will create a temporary breakpoint (will be deleted after being hit the first time)
        bp_add(addr, '-t')
    end

    def bp_do(action)
        if @debugger.send_mi_string(action)
            bp_parse
            return true
        else
            return false
        end
    end

    def bp_del(bp)
        bp_do("-break-delete #{bp.number}")
    end

    def bp_cond(bp, cond) # this breakpoint will now be ignored if #{condition} evaluates to 0
        bp_do("-break-condition #{bp.number} #{cond}")
    end

    def bp_after(bp, times) # this breakpoint will now be ignored #{times} times && activated afterwards
        bp_do("-break-after #{bp.number} #{times}")
    end

    def bp_disable(bp)
        bp_do("-break-disable #{bp.number}")
    end

    def bp_enable(bp)
        bp_do("-break-enable #{bp.number}")
    end

    # add wpt
    def watch_add(addr, mode = '')
        return false if mode != '-a' && mode != '-r' && mode != ''
        num = @debugger.send_mi_string("-break-watch #{mode} #{addr}")
        if num.first.content_type == 'done'
            bp_parse
            return @breakpoints[num.last.value['wpt']['number']] if mode == ''
            return @breakpoints[num.last.value['hw-rwpt']['number']] if mode == '-r'
            return @breakpoints[num.last.value['hw-awpt']['number']] if mode == '-a'
        else
            return false
        end
    end

    # add hw-awpt
    def watch_adda(addr)
        watch_add(addr, '-a')
    end

    # add hw-rwpt
    def watch_addr(addr)
        watch_add(addr, '-r')
    end

    def watch_del(bp)
        bp_do("-break-delete #{bp.number}")
    end

        def run()
            @debugger.send_mi_string("-exec-run")
        end

    def continue
        @debugger.send_mi_string('-exec-continue')
    end

    def stop
        @debugger.send_mi_string('-exec-interrupt')
    end

    # source line based step over
    def next
        @debugger.send_mi_string('-exec-next')
    end

    # source line based step into
    # untested
    def step
        @debugger.send_mi_string('-exec-step')
    end

    # asm based step over
    def nexti
        @debugger.send_mi_string('-exec-next-instruction')
    end

    # asm based step into
    def stepi
        @debugger.send_mi_string('-exec-step-instruction')
    end

    alias_method :step_into, :stepi
    alias_method :step_over, :nexti

    # Resumes the execution of the inferior program until the current function
    # is exited.  Displays the results returned by the function.
    def finish(mode = '')
        @debugger.send_mi_string("-exec-finish #{mode}")
    end

    # Resumes the reverse execution of the inferior program until the point
    # where current function was called.
    def finish_reverse
      finish('--reverse')
    end

    # Executes the inferior until the location specified in the argument is
    # reached. If there is no argument, the inferior executes until a source
    # line greater than the current one is reached.
    def exec_until(location = '')
        @debugger.send_mi_string("-exec-until #{location}")
    end

    # Resumes execution of the inferior program at the location specified by parameter.
    def jump(location)
        @debugger.send_mi_string("-exec-jump #{location}")
    end

    def read_mem(addr, count = 1, size = 1, format = 'x')
        res = @debugger.send_mi_string("-data-read-memory -- #{addr} #{format} #{size} 1 #{count}")
        return res.first.value['memory'].first['data'].map { |b| b.to_i(16).chr }.join('')
    end

    def read_ints(addr, count = 1, size = 1, format = 'x')
        res = @debugger.send_mi_string("-data-read-memory -- #{addr} #{format} #{size} 1 #{count} ")
        return res.first.value['memory'].first['data'].first.to_i
    end

    def read_uint8(addr, count = 1, size = 1, format = 'u')
        read_ints(addr, count, size, format)
    end

    def read_int8(addr, count = 1, size = 1, format = 'd')
        read_ints(addr, count, size, format)
    end

    def read_uint16(addr, count = 1, size = 2, format = 'u')
        read_ints(addr, count, size, format)
    end

    def read_int16(addr, count = 1, size = 2, format = 'd')
        read_ints(addr, count, size, format)
    end

    def read_uint32(addr, count = 1, size = 4, format = 'u')
        read_ints(addr, count, size, format)
    end

    def read_int32(addr, count = 1, size = 4, format = 'd')
        read_ints(addr, count, size, format)
    end

    def read_uint64(addr, count = 1, size = 8, format = 'u')
        read_ints(addr, count, size, format)
    end

    def read_int64(addr, count = 1, size = 8, format = 'd')
        read_ints(addr, count, size, format)
    end

    def gdb_var_set(var, val)
        res = @debugger.send_mi_string("-gdb-set #{var} #{val}")
        return true if res.first.content_type == 'done'
        return false
    end

    def gdb_var_show(var)
        res = @debugger.send_mi_string("-gdb-show #{var}")
        return res.first.value['value'] if res.first.content_type == 'done'
        return false
    end

    def disasm_cur
        res = @debugger.send_mi_string('-data-disassemble -s $pc -e "$pc+1" -- 0')
        return res.first.value['asm_insns'] if res.first.content_type == 'done'
        return false
    end

    def disasm_range(s, e)
        res = @debugger.send_mi_string("-data-disassemble -s #{s} -e #{e} -- 0")
        return res.first.value['asm_insns'] if res.first.content_type == 'done'
        return false
    end

    def cli_exec(cmd)
        res = @debugger.send_mi_string("-interpreter-exec console \"#{cmd}\"")
        return true if res.first.content_type == 'done'
        return false
    end

    def display_registers(number = '')
        res = @debugger.send_mi_string("-data-list-register-values x #{number}")
        return res.first.value['register-values'] if res.first.content_type == 'done'
    end

    def display_changed_registers
        res = @debugger.send_mi_string("-data-list-changed-registers")
        return res.first.value['register-values'] if res.first.content_type == 'done'
    end

    def display_register_names(number = '')
        res = @debugger.send_mi_string("-data-list-register-names #{number}")
        return res.first.value['register-names'] if res.first.content_type == 'done'
    end
  end
end
