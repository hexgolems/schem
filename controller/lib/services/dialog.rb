# TODO document me
module Schem
  # TODO document me
  class DialogService < BaseService
    include MonitorMixin

    def initialize(*args)
      super
      @spawners = []
    end

    def register_spawner(plugin)
      synchronize do
        @spawners << plugin
      end
    end

    def alert(text, blocking = true)
      from_json({ type: 'alert', text: text }, blocking)
    end

    def confirm(text, blocking = true)
      from_json({ type: 'confirm', text: text }, blocking)
    end

    def prompt(text, default = '', blocking = true)
      from_json({ type: 'prompt', text: text, default_value: default }, blocking)
    end

    def from_json(json, blocking = false)
      future = @spawners.last.display_dialog(json)
      return future.value if blocking
      future
    end
  end

  register_service(:dialog, DialogService)
end
