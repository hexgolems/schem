# encoding: utf-8
require_relative './lane.rb'

silence_warnings do
  require 'pry'
end

module Schem
  class DisassemblyLane < HexWidgetLane

    colspan 1

    action "leave" do |clicked,_|
      address = @plugin.goto_stack.pop
      if address
        @plugin.goto(address, 3, nil)
        update!
      end
    end

    action "enter" do |clicked,_|
      ins = srv.disasm_cache.get(clicked.min)
      if ins && ins.type.followable
        followable = ins.type.followable
        if followable.class == Metasm::Expression
          address = followable.rexpr
          @plugin.goto(address, 3, clicked.min)
        elsif followable.class == Metasm::Indirection
          expr_string = followable.target.lexpr.to_s + followable.target.op.to_s + followable.target.rexpr.to_s
          address = srv.expr_eval.evaluate expr_string
          @plugin.goto(address, 3, clicked.min)
        else
          raise "Followable class not known: #{followable.class}"
        end
        update!
      end
    end

    action "add breakpoint" do |clicked,_|
      srv.dbg.bp(clicked.min)
      update!
    end

    action "delete breakpoint" do |clicked,_|
      srv.dbg.bp_disable_at(clicked.min)
      update!
    end

    def get_address_ranges(address, lines, lines_before)
      @disasm = srv.disasm.lines(address, lines, lines_before)
      return @disasm.map{|i| i.range }
    end

    def get_line_reprs(address_range)
      instr = @disasm.find{|i| i.range.min == address_range.min }
      if instr.name == "byte"
        tags = []
        return [repr(instr.bin.bytes.map{|x| x.to_s(16).rjust(2,"0")}.join(" "),1, tags, ["raw"])]
      else
        tags = []
        tags_by_range = srv.tags.by_range(address_range).to_a

        tags_by_range.each do |t|
          next if t.type == :label || !t.name
          if t.data[:disasm_text]
            tags << tag(t.name,t.data[:disasm_text], t.data[:color])
          else
            tags << tag(t.name,nil, t.data[:color])
          end
        end
        classes = ["lv-max-width"]
        classes << "hl-ip" if address_range.include? srv.reg.ip
        instr_str = instr.name
        hl = case instr.type
          when InstructionType then srv.x86highlight.html(instr_str)
          when StringType then instr_str
          when UnknownType then instr_str
          when IntegerType then instr_str
        end
        hl = '<span class="hl-ip-color">▶</span>'+hl if address_range.include? srv.reg.ip
        hl = '<span class="hl-bp-color">■&nbsp;</span>'+hl if tags_by_range.any?{ |t| t.type==:breakpoint }
        return [repr(hl,1,tags,classes)]
      end
    end

  end
end
