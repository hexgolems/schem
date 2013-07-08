# encoding: utf-8
require_relative './plugin.rb'

class RedisPublisherPlugin < Schem::Plugin

  def auto_run
    @redis = redis_connection('sub')
    puts 'RedisPublisher online!'
    puts 'RedisPublisher publishing: "I like rainbows!"'
    @redis.publish(:test, 'I like rainbows!')
    sleep 0.5
    puts 'RedisPublisher publishing: "I like butteflies!"'
    @redis.publish(:test, 'I like butterflies!!')
    sleep 0.5
    puts 'RedisPublisher publishing: "exit"'
    @redis.publish(:test, 'exit')
  end

  def stop
    puts 'RedisPublisher offline!'
  end
end

# If you would like to run the plugin uncomment the next line
# register_plugin(RedisPublisherPlugin)
