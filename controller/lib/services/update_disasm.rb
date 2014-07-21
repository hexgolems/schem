# TODO document me
module Schem
  # TODO document me
  class DisasmUpdateService < BaseService
    def intialise(*args)
      super
    end

    def get_decoded(range)
      mem = srv.mem.read_raw_bytes(range.min, range.max - range.min + 1)
      dasm = Metasm::Shellcode.decode(mem, srv.obj.cpu_metasm)
      dasm.base_addr = range.min
      dasm = dasm.disassemble(range.min)
      decoded = dasm.decoded
      decoded
    end

    def update_types(decoded)
      decoded.each_pair do |_, ins|
        insert_into_bit(ins)
        srv.disasm_cache.invalidate(ins.address .. ins.address + ins.bin_length)
      end
    end

    def insert_into_bit(ins)
      address = ins.address
      length = ins.bin_length
      type = :instruction
      return true if srv.bit.set(address, type, length)
      name = ''
      range = address ... address + length
      type = :type_info
      data = { type: :instruction }
      srv.tags.add(Tag.new(name, range, type, data))
    end

    def disasm(range)
      decoded = get_decoded(range)
      update_types(decoded)
      true
    end
  end
  register_service(:disasm_updater, DisasmUpdateService)
end
