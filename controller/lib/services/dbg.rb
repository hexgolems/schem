# TODO document me
module Schem
  # TODO document me
  class DBGService < BaseService
    include GdbDebuggerApi
    def initialize(*args)
      super(*args)
      @cache = {}
      @debugger = @controller.debugger
      init_dbg_api
    end

    def get_internal_debugger_object
      @debugger
    end

    def executable_path
      @controller.path_to_exe
    end

    def bp(address)
      srv.tags.add(Tag.new(nil, (address..address), :breakpoint, enable: true))
      super
    end

    def bp_disable_at(address)
      tags_at_addr = srv.tags.by_address(address)
      bps = tags_at_addr.select { |x| x.type == :breakpoint }
      bps.each { |x| srv.tags.remove(x) }
      super
    end
  end

  register_service(:dbg, DBGService)
end
