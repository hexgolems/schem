# TODO comment
module Schem
  # TODO comment
  class DisasmCacheService < BaseService

    def initialize(*args)
      super
      @cache = {}
    end

    def invalidate(range)
      range.each do |address|
        del(address)
      end
    end

    def del(address)
      ins = @cache[address] 
      return unless ins
      @cache.delete ins.range.min
      @cache.delete ins.range.max
    end

    def add(instr)
      instr.range.each do |address|
        del(address)
      end
      @cache[instr.range.min] = instr
      @cache[instr.range.max] = instr
    end

    def get(address)
      @cache[address]
    end

  end
register_service(:disasm_cache, DisasmCacheService)
end
