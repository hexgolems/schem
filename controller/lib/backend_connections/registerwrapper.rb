# encoding: utf-8
require_relative './../include.rb'
require_relative './register.rb'

module Schem
  module RegisterWrapper
    def init_reg_wrapper
    end

    def registers
      internal_registers
    end

    def set_register(name, value)
      internal_set_register(name, value)
    end

    def get_register(_name)
      internal_get_registers
    end
  end
end
