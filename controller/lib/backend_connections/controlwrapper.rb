# encoding: utf-8
require_relative './../include.rb'

module Schem
  module ControlWrapper
    def init_control_wrapper
    end

    def get_mapped_images
      internal_get_mapped_images
    end

    def get_image_bin(id)
      internal_get_image_bin(id)
    end

    def restart
      internal_restart
    end

    def run
      internal_run
      @run_callbacks.each do |callback|
        callback.call
      end
    end

    def quit
      internal_quit
    end

    def step_over
      internal_step_over
    end

    def step_into
      internal_step_into
    end

    def continue
      internal_continue
    end
  end
end
