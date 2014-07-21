# TODO document me
module Schem
  class Type
    attr_accessor :range, :last_touched, :srv, :followable

    def initialize(srv, range)
      @range = range
      @last_touched = 0
      @srv = srv
      @followable = nil
    end

    def disasm(mem)
      [string_repr(mem), mem, @range]
    end
  end

  class UnknownType < Type
    def string_repr(mem)
      mem.hex_dump
    end
  end

  class InstructionType < Type
    def disassemble(mem)
      dasm = Metasm::Shellcode.decode(mem, srv.obj.cpu_metasm)
      dasm.base_addr = range.min
      dasm = dasm.disassemble(range.min)
      dasm.decoded
    end

    def determine_followable(ins)
      if ins.opcode.name =~ /\Acall|\Aj.+/
        if ins.instruction.args[0].respond_to? :symbolic
          @followable = ins.instruction.args[0].symbolic
        else
          @followable = ins.instruction.args[0]
        end
      end
    end

    def string_repr(mem)
      decoded = disassemble(mem)
      if decoded.include? range.min
        determine_followable(decoded[range.min])
        return decoded[range.min].instruction.to_s
      else
        return mem.hex_dump
      end
    end
  end

  class StringType < Type
    def string_repr(mem)
      '"' + mem.bytes.map { |byte| String.byte_repr(byte.chr, '\x' + byte.hex_dump(2)) }.join('') + '"'
    end
  end

  class IntegerType < Type
    attr_accessor :signed
    def initialize(srv, range, signed)
      super(srv, range)
      @signed = signed
    end

    def string_repr(mem)
      return srv.int.parse_signed(mem) if @signed
      srv.int.parse_unsigned(mem)
    end
  end

  # TODO document me
  class TypeService < BaseService
    def initialize(*args)
      super
    end

    def get_bit_types_at(address)
      type = srv.bit.get_as_disasm_type(address)
      return [] unless type
      [type]
    end

    def get_tag_types_at(address)
      types = srv.tags.by_address(address).select { |tag| tag.type == :type_info }
      return [] unless types.length > 0
      types.map do |t|
        type = case t.data[:type]
        when :string then StringType.new(srv, t.range)
        when :int then IntegerType.new(srv, t.range, t.data[:signed])
        when :instruction then InstructionType.new(srv, t.range)
        end
      end
    end

    def get_types_at(address)
      combined = get_bit_types_at(address) + get_tag_types_at(address)
      return [UnknownType.new(srv, address..address)] if combined.length == 0
      combined
    end

    def get_newest_type_at(address)
      types = get_types_at(address)
      return types.max_by { |x| x.last_touched } if types.length > 1
      types.first
    end
  end
  register_service(:types, TypeService)
end
