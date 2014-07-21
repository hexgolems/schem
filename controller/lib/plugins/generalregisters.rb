# encoding: utf-8
require_relative './plugin.rb'
require_relative './structview.rb'
require 'json'

module Schem
  class GeneralRegistersPlugin < StructViewPlugin
    def initialize(*args)
      super
      @old_regs = nil
    end

    depends_on(:reg)

    action 'edit' do |name|
      reg_value = srv.reg.get_value(name.to_sym)
      width = srv.obj.word_width
      if width == 32
        reg_length = srv.reg.reg_length32[name.to_sym]
      elsif width == 64
        reg_length = srv.reg.reg_length64[name.to_sym]
      else
        fail "word width #{width} not supported"
      end
      repr = srv.int.repr(reg_value, reg_length)
      answer_value = srv.dialog.prompt("Edit: #{name}\nhex: #{repr[:hex]}\nsigned:#{repr[:signed]}\nunsigned: #{repr[:unsigned]}", repr[1])['answer']
      next unless answer_value
      new_value = srv.int.to_unsigned(answer_value.to_i, reg_length)
      srv.reg.set(name, new_value)
      update!
    end

    action 'display' do |name|
      reg_value = srv.reg.get_value(name.to_sym)
      repr = srv.int.repr(reg_value, srv.reg.reg_length[name.to_sym])
      srv.dialog.alert "hex: #{repr[0]}\n signed:#{repr[1]}\nunsigned: #{repr[2]}"
    end

    def remove_unset(registers)
      registers = registers.map_values { |_k1, v1| v1.delete_if { |_k, v| v == 'nil' || v.nil? } }
      registers = registers.delete_if { |_k, v| v.empty? }
      registers = registers.map_keys { |k, v| if v.include?(k) then k else v.keys.first end }
      registers
    end

    def highlight_changed(registers)
      registers = remove_unset(registers)
      temp_registers = deep_copy(registers)
      if @old_regs.nil? || @old_regs == {}
        @old_regs = registers
      end
      registers.keys.each do |reg|
        registers[reg].keys.each do |sub_reg|
          if @old_regs[reg][sub_reg] != registers[reg][sub_reg]
            registers[reg][sub_reg] = '<span class="reg-changed">' + adjust(reg, sub_reg, registers[reg][sub_reg]) + '</span>'
          else
            registers[reg][sub_reg] = adjust(reg, sub_reg, registers[reg][sub_reg])
          end
        end
      end
      @old_regs = temp_registers
      registers
    end

    def adjust(reg, sub_reg, value)
      value = value[2..-1]
      adjust_range = srv.reg.general_purpose[srv.obj.word_width][reg][sub_reg]
      if adjust_range.min == 0
        zeros = (adjust_range.max + 1) / 4
        value = value.rjust(zeros, '0').rjust(16, ' ').gsub(' ', '&nbsp;')
      else
        zeros = ((adjust_range.max + 1) - adjust_range.min) / 4
        spaces = adjust_range.min / 4
        value = (value.rjust(zeros, '0') + ' ' * spaces).rjust(16, ' ').gsub(' ', '&nbsp;')
      end
      value
    end

    def get_data
      registers = srv.reg.x86_64_regs[:general_purpose] if srv.obj.word_width == 64
      registers = srv.reg.x86_32_regs[:general_purpose] if srv.obj.word_width == 32
      return { type: 'update', data: ['currently no registers available'] } unless registers
      # registers = registers.each_pair.inject({}){|h,(name,object)| h[name]=object.value["value"];h}
      registers = highlight_changed(registers)
      { type: 'update', data: registers }
    end
  end
  # If you would like to run the plugin uncomment the next line
  register_plugin(GeneralRegistersPlugin)
end
