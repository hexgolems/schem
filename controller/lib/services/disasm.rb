# TODO document me
module Schem
  class DisassembledInstruction
    attr_accessor :name, :bin, :range, :type
    def initialize(name, bin, range, type)
      @name = name
      @bin = bin
      @range = range
      @type = type
    end
  end

  # TODO document me
  class DisassemblyService < BaseService
    def initialize(*args)
      super
    end

    def lines(address, lines, lines_before)
      surround 'disam:lines' do
          instructions = [line_at(address)]
          lines_before.times do
            before_addr = instructions.first.range.min - 1
            instructions.unshift(line_at(before_addr))
          end
          lines_after = lines - lines_before - 1
          lines_after.times do
            after_addr = instructions.last.range.max + 1
            instructions << line_at(after_addr)
          end
          return instructions
        end
    end

    def line_at(address)
      cached_instr = srv.disasm_cache.get(address)
      if cached_instr
        mem = srv.mem.read_raw_bytes(cached_instr.range.min, cached_instr.range.size)
        if mem == cached_instr.bin
          return cached_instr
        end
      end
      type = srv.types.get_newest_type_at(address)
      range = ( type == :unknown ? (address .. address) : type.range)
      mem = srv.mem.read_raw_bytes(range.min, range.size)
      new_disasm = get_disasm(mem, type, address)
      srv.disasm_cache.add(new_disasm)
      new_disasm
    end

    def get_disasm(mem, type, _address)
      name, bin, range = type.disasm(mem)
      res = DisassembledInstruction.new(name, bin, range, type)
      res
    end
  end
  register_service(:disasm, DisassemblyService)
end
