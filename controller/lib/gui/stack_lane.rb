# encoding: utf-8
module Schem
  class StackLane < HexWidgetLane
    colspan 1

    def get_int_representation(address, sign)
      int = srv.mem.read_int(address, sign, @plugin.byte_width / 8)
      int.to_s
    end

    def get_hex_representation(address)
      int = srv.mem.read_int(address, :unsigned, @plugin.byte_width * 8)
      int.to_s(16).rjust(@plugin.byte_width * 2, '0')
    end

    def get_representation(address)
      types = srv.tags.by_address(address).select { |tag| tag.type == :type_info }
      int_type = types.find { |t| t.data[:type] == :int }
      if int_type
        return get_int_representation(address, int_type.data[:signed] ? :signed : :unsigned)
      end
      return get_hex_representation(address) unless types.length > 0
    end

    def get_tags(address)
      tags = srv.tags.by_range(address..address).select(&:name)
      tag_repr = tags.map { |t| tag(t.name, t.data[:info_string], t.data[:color]) }
    end

    def get_line_reprs(address_range)
      res = []
      ranges = srv.mem.get_mapped_memory(address_range)
      ranges.each do |is_mapped, range|
        if is_mapped == :valid
          address = range.min
          desc = get_representation(address)
          res << repr(desc, 1, get_tags(address))
        else
          res << repr('unmapped', 1)
        end
      end
      res
    end
  end
end
