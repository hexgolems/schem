# encoding: utf-8
# TODO document me

require 'tempfile'
require 'metasm'

module Schem
  class FileImage
    attr_assert :format, any_of(:pe, :elf)
    attr_assert :path, String
    attr_reader :name
    attr_accessor :range, :srv
    include MonitorMixin

    def initialize(id, range, srv)
      super()
      @id = id
      @range = range
      @srv = srv
      @name = nil
    end

    def set_name(content)
      @name ||= 'img:' + Digest::SHA512.hexdigest(content)
    end

    def get_section_name(section)
      'section:bit:' + Digest::SHA512.hexdigest(section[:data])
    end

    def known_image?(section_infos)
      known = true
      section_infos.each do |s|
        key = get_section_name(s)
        value_under_key = srv.db[key]
        return false unless value_under_key
        length = value_under_key.length
        known = false unless length == s[:length]
      end
      known
    end

    def disect(content)
      set_name(content)
      synchronize do
        file = Tempfile.open('object_file') do |f|
          path = f.path
          f.print(content)
          f.close
          @exe = Metasm::AutoExe.decode_file(path)
          @dasm = @exe.disassembler
          section_infos = srv.bitextractor.get_sections(@dasm)
          if !known_image?(section_infos)
            @dasm.backtrace_maxblocks_data = -1
            surround('srv:metasm_extractor', "Dissasembling #{ @id.inspect } as #{ @exe.cpu.class }") do
              @exe.disassemble_fast_deep
            end
          else
            Log.info('disassembly', "No disassembly needed, image already known. name: #{@name}, id: #{@id}")
          end
          srv.bitextractor.create_bit(self)
          srv.metasm_extractor.extract(self)
        end
      end
    end

    def with_dasm(&block)
      synchronize do
        block.call(@dasm)
      end
    end

    def shared_object?
      return false if @exe.header.type == 'EXEC'
      true
    end

    def rva_to_va(rva)
      return @range.min + rva if shared_object?
      rva # executables use rva in metasm
    end

    def va_to_rva(va)
      return va - @range.min if shared_object?
      rva - 0x400000 # TODO WTF WTF WTF this is so fucking broken
    end
    # maps an address used by the metasm disassembler to a VA in the process memory
    def map_address(addr)
      addr # TODO
    end
    # def get_endianness
    #     @dasm.sections.values.map { |x| x.reloc unless x.reloc.empty? }.compact.first.first.last.endianness
    #   end
  end

  # TODO document me
  class ObjectService < BaseService
    attr_assert :arch, any_of(:x86)
    attr_assert :word_width, any_of(32, 64)
    attr_assert :endianness, any_of(:little_endian, :big_endian)
    attr_reader :cpu_metasm
    attr_accessor :main_executable

    def initialize(*args)
      super
      @images_by_id = {}
    end

    def set_arch_specifics
      exe = Metasm::AutoExe.decode_file(srv.dbg.executable_path)
      dasm = exe.disassembler
      @arch = :x86
      @word_width = exe.bitsize
      @endianness = exe.endianness
      @cpu_metasm = exe.cpu.class.new
    end

    def init_callback
      check_for_new_images
      set_arch_specifics
    end

    def get_images
      @images_by_id
    end

    def get_image(address)
      imageid, range = @images.each_pair.find { |_imageid, range| range.include? address }
      return nil unless range
      @images_by_id[imageid]
    end

    def stop_callback
      check_for_new_images
    end

    def check_for_new_images
      @images_to_ranges ||= {}
      images_to_ranges = srv.dbg.get_mapped_images
      if images_to_ranges.keys != @images_to_ranges.keys
        (images_to_ranges.keys - @images_to_ranges.keys).each do |imgid|
          range = images_to_ranges[imgid]
          if images_to_ranges.each_pair.any? { |img, irange| (range.intersection(irange) && img != imgid) }
            Log.error('colliding images') && next
          end
          load_image(imgid, range)
        end
      end
      @images_to_ranges = images_to_ranges
    end

    def load_image(imgid, range)
      img = FileImage.new(imgid, range, srv)
      @images_by_id[imgid] = img
      content = nil
      begin
        content = srv.dbg.get_image_bin(imgid)
      rescue Errno::ENOENT => e
        content = nil
      end
      return unless content
      img.disect(content)
    end
  end
  register_service(:obj, ObjectService)
end
