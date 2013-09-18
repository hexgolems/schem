# encoding: utf-8
require_relative './../include.rb'
require_relative './memorysection.rb'

module Schem
  module MemoryWrapper

    def init_memory_wrapper
    end

    def mem_read(address, length)
      return internal_mem_read(address, length)
    end

    def mem_write(address, string)
      return internal_mem_write(address, string)
    end

    def mem_mappings
      return internal_mem_mappings
    end

  end
end
