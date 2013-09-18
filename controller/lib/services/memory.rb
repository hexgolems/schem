require 'pry'

# TODO document me
module Schem
  # TODO document me
  class MemoryService < BaseService

    include MonitorMixin

    def stop_callback
      @cache.clear
      reload
    end

    def quit_callback
      @cache.clear
    end

    def initialize(*args)
      super(*args)
      @cache = {}
      @old_mapped_memory = nil
      reload
    end

    def reload
      publish(:mapped_memory) do
        mapped_memory = @controller.debugger.mem_mappings
        if @old_mapped_memory != mapped_memory
          signal_waiting
          @old_mapped_memory = mapped_memory
        end
        mapped_memory
      end
    end

    def find(addr)
      get_published_value(:mapped_memory).each do |sec|
        return sec if sec.from <= addr && addr <= sec.to
      end
      return false
    end

    def get_mapped_memory(range)
      assert { range.first <= range.last }
      @mapped = mapped_memory
      # find all intersecting subranges
      intersections = @mapped.sort_by { |x| x.from }.map { |sec| sec.intersection(range) }.compact

# removed this part, because if they are next to each other they are most
# propably still two different sections, and that makes other stuff easier
#
# if there are two regions that are mapped without a hole inbetween, merge the resulting subranges
#     intersections = intersections.inject([]) do |s,e|
#       if s.last && s.last.max >= e.min-1
#               s[-1]= (s.last.min..e.max) ; s
#       else
#               s << e; s
#       end
#     end

      # all the intersetcions are indeed valid maped regions
      intersections = intersections.map { |one_range| [:valid, one_range] }
      # now add the invalid reagions between the mapped ones
      res = []
      intersections.each_index do |i|
        res << intersections[i]
        if i + 1 < intersections.length and ! (intersections[i][1].max + 1) == intersections[i + 1][1].min
                res << [:invalid, ((intersections[i][1].max + 1)..(intersections[i + 1][1].min - 1))]
        end
      end
      # add invalid regions at start and end if necessary
      res = [[:invalid, range]] if res.length == 0
      res = [[:invalid, range.min..(res.first[1].min - 1)]] + res if res.first[1].min > range.min
      res << [:invalid, (res.last[1].max + 1)..range.max] if res.last[1].max + 1 <= range.max
      return res
    end

    def write_raw_bytes(address, str)
      synchronize do
        @cache.clear
        srv.dbg.mem_write(address, str)
        update(written_to: (address..(address + str.length - 1)))
      end
    end

    def lookup_cache(req_range)
      cached = @cache.keys.find{|cached| cached.contains_range?(req_range) }
      return nil unless cached
      offset = req_range.min-cached.min
      len = req_range.max-req_range.min+1
      return @cache[cached][offset...offset+len]
    end

    def add_to_cache(range, memory_string)
      @cache[range] = memory_string
    end

    def put_memory_in_cache(range)
      expanded_range = (range.min-100...[range.max,range.min+600].max)
      mapped = get_mapped_memory(expanded_range)
      _,mapped = mapped.find{|(s,range)| s==:valid && range.contains_range?(range) }
      assert { mapped != nil }
      add_to_cache(mapped, srv.dbg.mem_read(mapped.min, mapped.max-mapped.min+1) )
    end

    #TODO srv.mem.read_raw_byte(range) instead of address, length
    def read_raw_bytes(address, length)
      synchronize do
        requested = (address...address+length)
        ensure_request_is_in_consecutive_memory_block = get_mapped_memory(requested).length
        assert { ensure_request_is_in_consecutive_memory_block == 1 }
        cached = lookup_cache(requested)
        return cached if cached
        put_memory_in_cache(requested)
        return lookup_cache(requested)
      end
    end

    # bytes = 1,2,4,8
    # signed = :singed, :unsigned
    def get_integer_unpack(signed, bytes)
      pack_str = { 1 => 'C', 2 => 'S', 4 => 'L', 8 => 'Q' }[bytes]
      pack_str.downcase! if signed == :signed
      return pack_str
    end

    # bitsize = 8,16,32,64
    # signed = :singed, :unsigned
    def read_int(address, signed, bit_size)
      byte_size = bit_size / 8
      mem = read_raw_bytes(address, byte_size)
      return mem.unpack(get_integer_unpack(signed, byte_size))[0]
    end

    def write_int(address, signed, bit_size, val)
      byte_size = bit_size / 8
      mem = [val].pack(get_integer_unpack(signed, byte_size))
      return write_raw_bytes(address, mem)
    end

    # bit_size = 8, 16, 32, 64 size of the items
    # array_length = amount of array entries to return
    # signed = :singed, :unsigned
    def read_int_array(address, array_length, bit_size,  signed = :unsigned)
      byte_size = bit_size / 8
      byte_length = byte_size * array_length
      mem = read_raw_bytes(address, byte_length)
      format = get_integer_unpack(signed, byte_size) + array_length.to_s
      res = mem.unpack(format)
      return res
    end

    def read_uint8(address)
      read_int(address, :unsigned, 8)
    end

    def read_int8(address)
      read_int(address, :signed, 8)
    end

    def read_uint16(address)
      read_int(address, :unsigned, 16)
    end

    def read_int16(address)
      read_int(address, :signed, 16)
    end

    def read_uint32(address)
      read_int(address, :unsigned, 32)
    end

    def read_int32(address)
      read_int(address, :signed, 32)
    end

    def read_uint64(address)
      read_int(address, :unsigned, 64)
    end

    def read_int64(address)
      read_int(address, :signed, 64)
    end

  end

  register_service(:mem, MemoryService)

end
