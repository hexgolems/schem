module Schem

  class HexLane < HexWidgetLane

    colspan 16

    action "inc" do |clicked_range, selected_range|
      len = (selected_range.max-selected_range.min+1)
      return srv.dialog.alert("please select 1,2,4 or 8 bytes") unless [1,2,4,8].include?(len)
      val = srv.mem.read_int(selected_range.min, :signed, len*8)
      srv.mem.write_int(selected_range.min, :signed, len*8, val+1)
      update!
    end

    action "as uint" do |clicked_range, selected_range|
      len = (selected_range.max-selected_range.min+1)
      return srv.dialog.alert("please select 1,2,4 or 8 bytes") unless [1,2,4,8].include?(len)
      srv.tags.add( Tag.new(nil,selected_range,:type_info, {type: :int, size: len, signed: false}) )
      update!
    end

    action "as int" do |clicked_range, selected_range|
      len = (selected_range.max-selected_range.min+1)
      return srv.dialog.alert("please select 1,2,4 or 8 bytes") unless [1,2,4,8].include?(len)
      srv.tags.add( Tag.new(nil,selected_range,:type_info, {type: :int, size: len, signed: true}) )
      update!
    end

    action "as raw" do |clicked_range, selected_range|
      tags = srv.tags.by_range(selected_range)
      tags = tags.select{|x| x.type == :type_info }
      tags.each { |tag| srv.tags.remove(tag) }
      update!
    end

    def get_hex_representation(address)
      int = srv.mem.read_int(address,:unsigned,8)
      return 1, int.hex_dump(2)
    end

    def get_int_representation(address,sign,size)
      int = srv.mem.read_int(address,sign, size)
      prefix = {8 => "B", 16=> "W", 32 => "D", 64 => "Q"}[size]
      return size/8, "#{prefix}#{int}"
    end

    def get_representation(address)
      types = srv.tags.by_address(address).select{|tag| tag.type == :type_info}
      return get_hex_representation(address) unless types.length > 0
      type = types.min_by{|t| (t.range.min-address).abs}
      case type.data[:type]
      when :int
        width,desc = get_int_representation(type.range.min,type.data[:signed]? :signed : :unsigned,type.data[:size]*8)
        return width-(address-type.range.min), desc
      when :string
        byte = srv.mem.read_raw_bytes(address,1)
        return 1,String.byte_repr(byte,byte.ord.hex_dump(2))
      else
        return get_hex_representation(address)
      end
    end

    def get_tags(address, width)
      tags = srv.tags.by_range(address...address+width).select{|t| t.name }
      tag_repr = tags.map{|t| tag(t.name, t.data[:info_string], t.data[:color]) }
    end

    def get_line_reprs(address_range)
      res = []
      ranges = srv.mem.get_mapped_memory(address_range)
      ranges.each do |is_mapped, range|
        if is_mapped == :valid
          address = range.min
          loop do
            width, desc = get_representation(address)
            assert { width > 0 }
            if width + address > address_range.max + 1
              res << repr( "...", address_range.max-address + 1)
              break
            end
            res << repr( desc, width , get_tags(address, width))
            address += width
            break if address > range.max
          end
        else
          res << repr("unmapped", (range.max-range.min+1))
        end
      end
      return res
    end

  end
end
