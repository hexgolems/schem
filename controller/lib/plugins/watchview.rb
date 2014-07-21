# encoding: utf-8
require_relative './plugin.rb'
require_relative './structview.rb'
require 'json'

module Schem
  class WatchExpressionPlugin < StructViewPlugin
    depends_on(:on_stop, :reg, :mem)

    action 'add' do |_|
      expr = srv.dialog.prompt('enter an expression', 'read_uint64(ebp+8)')['answer']
      add_watch_expression(expr)
      update!
    end

    action 'delete' do |name|
      delete_watch_expression(name)
      update!
    end

    def initialize(*args)
      super
      @watch_expressions = {}
      add_watch_expression('ret', 'read_uint64(ebp)')
      add_watch_expression('eax+100')
    end

    def get_data
      { type: 'update', data: @watch_expressions.map_values { |_k, v| srv.expr_eval.evaluate(v) rescue [$ERROR_INFO, $ERROR_POSITION] } }
    end

    def add_watch_expression(name = nil, string)
      return @watch_expressions[name] = string if name
      @watch_expressions[string] = string
    end

    def delte_watch_Expression(name)
      @watch_expressions.delte(name)
    end
  end
  # If you would like to run the plugin uncomment the next line
  register_plugin(WatchExpressionPlugin)
end
