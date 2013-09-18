require 'monitor'
require 'metasm'

# TODO document me
module Schem

  # TODO document me
  class MetasmService < BaseService

    attr_reader :decoded

    include MonitorMixin

    def initialize(*args)
      super(*args)
    end

    def init_callback
      @redis = srv.redis.connection
    end

    def get_tags_name(img)
      return "tags:"+img.name
    end

    def get_cached_tags(img)
      value = @redis.get(get_tags_name(img))
      return Marshal.load(value) if value
      return nil
    end

    def store_cached_tags(img,tags)
      @redis.set(get_tags_name(img), Marshal.dump(tags))
    end

    def extract(image_obj)
      tags =  get_cached_tags(image_obj)
      if !tags
        tags = extract_tags(image_obj)
        store_cached_tags(image_obj, tags)
      end
      tags.each do |tag|
        tag.range = (image_obj.rva_to_va(tag.range.min)..image_obj.rva_to_va(tag.range.max))
        srv.tags.add(tag)
      end
    end

    def extract_tags(image_obj)
      tags = []
      image_obj.with_dasm do |dasm|
        tags += get_simple_labels(image_obj)
        tags += get_string_labels(image_obj)
        tags += get_function_block_labels(image_obj)
      end
      return tags
    end

    def get_simple_labels(image_obj)
      tags = []
      image_obj.with_dasm do |dasm|
        dasm.label_alias.each_pair do |address, labels|
          address = image_obj.map_address(address)
          labels.each do |l|
            tags << Tag.new(l, (address..address), :label)
          end
        end
      end
      return tags
    end
    private :get_simple_labels

    def get_string_labels(image_obj)
      tags = []
      image_obj.with_dasm do |dasm|
        dasm.strings_scan.each do |address, str|
          address = image_obj.map_address(address)
          tags << Tag.new(
                "'#{ str.inspect[1..-2] }'",
                (address..address + str.length),
                :type_info, {type: :string})
        end
      end
      return tags
    end
    private :get_string_labels

    def get_function_block_labels(image_obj)
      tags = []
      image_obj.with_dasm do |dasm|
        dasm.function.values.each do |func|
          blocks = get_function_blocks(dasm,func)
          next unless blocks.length > 0
          faddress = blocks[0].address
          name = dasm.get_label_at(faddress)
          blocks.each do |block|
            from = image_obj.map_address(block.address)
            to = image_obj.map_address((block.address + block.bin_length-1))
            range = (from..to)
            tags << Tag.new("#{name}.#{(block.address - faddress)}", range, :function_block)
          end
        end
      end
      return tags
    end
    private :get_function_block_labels


    def get_function_blocks(dasm,func)
        blocks = dasm.function_blocks(func)
        blocks.keys.map { |address| dasm.block_at(address) }
    end

  end
  register_service(:metasm_extractor, MetasmService)
end
