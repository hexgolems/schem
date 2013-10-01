module Schem

  # The InferredType class offers functionality for storing information about
  # memory value types
  class InferredType

    attr_accessor :type, :continued, :signed, :struct, :byte, :length, :address

    TYPES = { 0 => :undefined, 1 => :instruction, 2 => :pointer, 3 => :string,
             4 => :int8, 5 => :int16, 6 => :int32, 7 => :int64,
             instruction: 1, undefined: 0, pointer: 2, string: 3,
             int8: 4, int16: 5, int32: 6, int64: 7
     }

    def initialize
      @length = 0
    end

    def ==(other)
      return false unless self.type == other.type
      return false unless self.continued == other.continued
      return false unless self.signed == other.signed
      return false unless self.struct == other.struct
      return false unless self.byte == other.byte
      return true
    end

    def self.from_byte(byte, address = nil)
      t = InferredType.new
      t.type = TYPES[(byte.ord & 7)]
      t.continued = (byte.ord[3]) == 1
      t.signed = (byte.ord[4]) == 1
      t.struct = (byte.ord[5]) == 1
      t.byte = byte
      t.address = address
      return t
    end

    def self.from_type(type, flags = { })
      t = InferredType.new
      t.type = type
      t.continued = flags[:continued] || false
      t.signed = flags[:signed] || false
      t.struct = flags[:struct] || false
      t.byte = self.to_byte(type, flags)
      return t
    end

    def self.to_byte(type, flags)
      byte = TYPES[type]
      byte |= 2**3 if flags[:continued] == true
      byte |= 2**4 if flags[:signed] == true
      byte |= 2**5 if flags[:struct] == true
      return byte
    end

  end


  # Bitmap for storing and accessing inferred types
  class TypeInformationBitmap

    attr_reader :range, :length, :name, :reused

    def initialize(name, img, range, srv)
      @srv = srv
      @name = name
      @length = range.size
      @range = range
      @reused = true
      previous_content = srv.db[@name]
      if !previous_content || previous_content.length != @length
        @reused = false
        srv.db[@name] = "\0" * @length
      end
    end


    def inspect
      return '<class: ' + self.class.to_s + ', name: ' + @name.to_s + ', length: ' + @length.to_s + ' , range:' + @range.min.to_s + '..' + @range.max.to_s + ' >'
    end

    FROM_TYPES = {
      undefined: (InferredType.from_type(:undefined).byte.chr),
      int8: (InferredType.from_type(:int8, signed: true).byte.chr),
      uint8: (InferredType.from_type(:int8, signed: false).byte.chr),
      int16: (InferredType.from_type(:int16, signed: true).byte.chr + InferredType.from_type(:int16, { signed: true, continued: true }).byte.chr),
      uint16: (InferredType.from_type(:int16, signed: false).byte.chr + InferredType.from_type(:int16, { signed: false, continued: true }).byte.chr),
      int32: (InferredType.from_type(:int32, signed: true).byte.chr + InferredType.from_type(:int32, { signed: true, continued: true }).byte.chr * 3),
      uint32: (InferredType.from_type(:int32, signed: false).byte.chr + InferredType.from_type(:int32, { signed: false, continued: true }).byte.chr * 3),
      int64: (InferredType.from_type(:int64, signed: true).byte.chr + InferredType.from_type(:int64, { signed: true, continued: true }).byte.chr * 7),
      uint64: (InferredType.from_type(:int64, signed: false).byte.chr + InferredType.from_type(:int64, { signed: false, continued: true }).byte.chr * 7),
      instruction: (InferredType.from_type(:instruction).byte.chr),
      instruction_continued: (InferredType.from_type(:instruction, { continued: true }).byte.chr),
      pointer: (InferredType.from_type(:pointer).byte.chr),
      pointer_continued: (InferredType.from_type(:pointer, { continued: true }).byte.chr),
      string: (InferredType.from_type(:string).byte.chr),
      string_continued: (InferredType.from_type(:string, { continued: true }).byte.chr)
     }

    TYPE_LENGTH = {
      undefined: 1, int8: 1, uint8: 1, int16: 2, uint16: 2, int32: 4, uint32: 4, int64: 8, uint64: 8
     }

    def type_string(type, length = 0)
      string = FROM_TYPES[type]
      raise "unknown type #{type.inspect}" unless string
      (length-1).times { string += FROM_TYPES[(type.to_s + '_continued').to_sym] }
      return string
    end

    def to_rva(address)
      if !@range.include?(address)
      raise "address #{address.to_s 16} not in range #{@range.hex_inspect}"
      end
      return address - @range.min
    end

    def get_byte_types_from_string(string,address)
      string.each_byte.with_index.map { |x,i| InferredType.from_byte(x, address+i)}
    end

    def get_type_string(range)
      raise "invalid range" unless range.intersection @range
      overflow_top = ""
      overflow_bottom = ""
      if range.max > @range.max
        overflow_top = type_string(:undefined)*(range.max-@range.max)
        range = (range.min..@range.max)
      end
      if range.min < @range.min
        overflow_bottom = type_string(:undefined)*(@range.min-range.min)
        range = (@range.min..range.max)
      end

      range_rva = (to_rva(range.min)..to_rva(range.max))

      return overflow_bottom+bit_get_range(range_rva)+overflow_top
    end

    def bit_get_range(rva_range)
        return @srv.db[@name][rva_range.min..rva_range.max]
    end

    def bit_set_range(rva,string)
      @srv.db[@name][rva...rva+string.length] = string
      return string
    end

    def set_type_string(address, string)
      range = (address...(address+string.length))
      raise "invalid range" unless @range.include?(range.min) && @range.include?(range.max)
      bit_set_range to_rva(address), string
    end

    def get_byte_types(range)
      get_byte_types_from_string(get_type_string(range), range.min)
    end

    def get_prefix_byte_types(address)
      types = []
      loop do
        address -= 1
        type = get_byte_types(address..address).first
        types.unshift type
        return types if !type.continued
      end
    end

    def get_postfix_byte_types(address)
      types = []
      loop do
        address += 1
        type = get_byte_types(address..address).first
        return types if !type.continued
        types << type
      end
    end

#this function will return an array containing all the types that intersect the given range (again as byte infos)
    def get_expanded_byte_types(range)
      types = get_byte_types(range) #get one byte more so we can check if the last type is continued
      types = get_prefix_byte_types(range.min)+types if types.first.continued
      types += get_postfix_byte_types(range.max)
      return types
    end

#this function will set all types that intersect the given range to
#undefined (used before writing types such that no unfinished types remain at
#the border
    def fix_overwritten(range)
      types = get_expanded_byte_types(range)
      range = types.first.address..types.last.address
      set_type_string(range.min, type_string(:undefined)*range.size)
    end

    def types(range)
      expanded = get_expanded_byte_types(range)
      types = []
      expanded.each do |byte_type|
        types << byte_type unless byte_type.continued
        types.last.length += 1
      end
      return types
    end


    def set_type(address,type,length=nil)
      type_repr = type_string(type,length)
      range = address...address+type_repr.length
      fix_overwritten(range)
      set_type_string(address,type_repr)
    end

  end
end
