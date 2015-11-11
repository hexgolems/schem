# encoding: utf-8
# TODO document me
module Schem
  # TODO document me
  class KnowledgeBaseService < BaseService
    include MonitorMixin

    def initialize(*args)
      super
      @knowledge = {}
    end

    def []=(key, val)
      synchronize do
        @knowledge[key] = val
      end
    end

    def [](key)
      synchronize do
        @knowledge[key]
      end
    end
  end

  register_service(:db, KnowledgeBaseService)
end
