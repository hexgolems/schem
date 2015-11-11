# encoding: utf-8
module Schem
  # The BitExtractor extracts information from Metasm and puts it into a Bitmap for Inferred Types (BIT)
  class BitExtractorService < BaseService
    attr_reader :bitmaps

    def initialize(*args)
      super
    end

    def create_bit(img)
      surround 'create bitmap' do
        create_bitmaps_for_sections(img)
      end
    end

    def create_new_bitmap(name, img, range)
      t = TypeInformationBitmap.new(name, img, range, srv)
      srv.bit.bitmaps[name] ||= t
      t
    end

    def find_bitmap(address)
      bitmaps = srv.bit.bitmaps
      keys = bitmaps.keys.select { |x| bitmaps[x].range.include? address }
      fail "found #{keys.length} bitmaps" unless keys.length == 1
      bitmaps[keys.first]
    end

    def fill_bitmap(img, bit)
      img.with_dasm do |dasm|
        decoded = dasm.decoded
        decoded.each_value do |value|
          next if value == true # because sometimes metasm thinks it should return {0 => true}
          va = img.rva_to_va(value.address)
          next unless bit.range.include? va
          bit.set_type(va, :instruction, value.bin_length) unless bit.reused
        end
      end
      true
    end

    def create_bitmaps_for_sections(img)
      img.with_dasm do |dasm|
        get_sections(dasm).each do |s|
          name = img.get_section_name(s)
          range = (img.rva_to_va(s[:start])...img.rva_to_va(s[:start] + s[:length]))
          # TODO fix this
          Log.error('colliding sections') && next if srv.bit.bitmaps.values.any? { |bit| bit.range.intersection range }
          bit = create_new_bitmap(name, img, range)
          fill_bitmap(img, bit)
        end
      end
      srv.bit.bitmaps
    end

    def get_sections(dasm)
      section_info = []
      sections = dasm.sections
      section_info = sections.each_pair.map do |k, v|
        { start: k, length: v.virtsize, data: v.data }
      end
      section_info
    end

    register_service(:bitextractor, BitExtractorService)
  end
end
