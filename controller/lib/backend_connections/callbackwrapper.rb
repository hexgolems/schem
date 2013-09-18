# encoding: utf-8
require_relative './../include.rb'

module Schem
  module CallbackWrapper
    def init_callback_wrapper
      @run_callbacks = Set.new
    end

    def on_execute(&block)
      return internal_on_execute(&block)
    end

    def on_quit(&block)
      return internal_on_quit(&block)
    end

    def on_stop(&block)
      return internal_on_stop(&block)
    end

    def on_run(&block)
      @run_callbacks.add(block)
    end
  end
end
