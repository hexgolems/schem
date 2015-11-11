# encoding: utf-8
# TODO document me
module Schem
  # TODO document me
  class OnStopService < BaseService
    def initialize(*args)
      super
      publish(:dbg_available?) { false }
    end

    def stop_callback
      signal_waiting
      publish(:dbg_available?) { true }
    end

    def execute_callback
      publish(:dbg_available?) { false }
    end
  end
  register_service(:on_stop, OnStopService)
end
