require 'redis'

# TODO document me
module Schem

  # TODO document me
  class RedisService < BaseService

    def initialize(*args)
      @redis_by_thread = {}
      super
    end

    def connection
      Thread.current[:redis_connection_schem] ||= @controller.new_redis_connection
    end

  end
  register_service(:redis, RedisService)
end
