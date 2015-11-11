# encoding: utf-8
require 'pry'

module Schem
  # Service for storing and retrieving inferred types
  class ExpressionEvalService < BaseService
    def initialize(*args)
      super
    end

    def evaluate(string)
      eval(string, binding)
    end

    def method_missing(name, *args)
      return srv.reg.send(name, *args) if srv.reg.respond_to? name
      return srv.reg.get_value(name) if srv.reg.registers.include? name.to_s
      return srv.mem.send(name, *args) if srv.mem.respond_to? name
      super
    end

    register_service(:expr_eval, ExpressionEvalService)
  end
end
