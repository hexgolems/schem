# encoding: utf-8
require_relative './plugin.rb'
require_relative './structview.rb'
require 'json'

module Schem
  class SpecialRegistersPlugin < StructViewPlugin
    depends_on(:reg)

    def X86_64registers
      # TODO
    end

    action 'toggle' do |name|
      srv.reg.toggle_flag(name.to_sym)
    end

    def get_data
      registers = deep_copy(srv.reg.x86_64_regs) if srv.obj.word_width == 64
      registers = deep_copy(srv.reg.x86_32_regs) if srv.obj.word_width == 32
      registers.delete(:general_purpose)
      return { type: 'update', data: ['currently no registers available'] } unless registers
      # registers = registers.each_pair.inject({}){|h,(name,object)| h[name]=object.value["value"];h}
      registers = highlight_changed(registers)
      { type: 'update', data: registers }
    end

    def rflags_as_string(old_rflags, rflags)
      r = { 'R+'.to_sym => '+', 'R-'.to_sym => '-', RZ: 'Z', RN: 'N' } # TODO
      rflags.map do |(s, v)|
        s = r[s] if r.include? s
        if v == 0
          if old_rflags[s] == rflags[s]
            next s.to_s[0].downcase
          else
            next '<span class="reg-changed">' + s.to_s[0].downcase + '</span>'
          end
        else
          if old_rflags[s] == rflags[s]
            next s.to_s[0]
          else
            next '<span class="reg-changed">' + s.to_s[0] + '</span>'
          end
        end
      end.join('')
    end

    def highlight_changed(registers)
      temp_registers = deep_copy(registers)
      if @old_regs.nil? || @old_regs == {}
        @old_regs = registers
        # return registers
      end
      registers.keys.each do |group|
        if registers[group].class != Hash
          if @old_regs[group] != registers[group]
            registers[group] = '<span class="reg-changed">' + registers[group].to_s + '</span>'
          end
        else
          registers[group].keys.each do |reg|
            if registers[group][reg].class != Hash
              if @old_regs[group][reg] != registers[group][reg]
                reg_val = registers[group][reg]
                if reg_val
                  formated = '<span class="reg-changed">' + reg_val.to_s + '</span>'
                  registers[group][reg] = formated
                end
              end
            else
              registers[group][reg].keys.each do |sub_reg|
                if @old_regs[group][reg][sub_reg] != registers[group][reg][sub_reg]
                  subreg_val = registers[group][reg][sub_reg]
                  if subreg_val
                    formated = '<span class="reg-changed">' + subreg_val.to_s + '</span>'
                    registers[group][reg][sub_reg] = formated
                  end
                end
              end
            end
          end
        end
      end
      registers[:flags][:flags] = rflags_as_string(@old_regs[:flags], temp_registers[:flags])
      registers[:mxcsr][:mxcsr] = rflags_as_string(@old_regs[:mxcsr], temp_registers[:mxcsr])
      @old_regs = temp_registers
      registers
    end
  end
  # If you would like to run the plugin uncomment the next line
  register_plugin(SpecialRegistersPlugin)
end
