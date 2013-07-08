# encoding: utf-8
require_relative './plugin.rb'
require 'redis'

class RedisSubscriberPlugin < Schem::Plugin

  def subscription_handler(on)
    on.subscribe do |channel, subscriptions|
      puts "RedisSubscriber subscribed to ##{channel} (#{subscriptions} subscriptions)"
    end

    on.message do |channel, message|
      puts "RedisSubscriber received: #{message} on channel #{channel}"
      @redis.unsubscribe if message == 'exit'
    end

    on.unsubscribe do |channel, subscriptions|
      puts "RedisSubscriber: unsubscribed from ##{channel} (#{subscriptions} subscriptions)"
    end
  end

  def auto_run
    puts 'RedisSubscriber online!'
    @redis = redis_connection('sub')
    begin
      @redis.subscribe(:test) { |on| subscription_handler(on) }
    rescue Redis::BaseConnectionError => error
      puts "#{error}, retrying in 1s"
      sleep 1
      retry
    end
  end

  def stop
    puts 'RedisSubscriber offline!'
  end
end

# If you would like to run the plugin uncomment the next line
# register_plugin(RedisSubscriberPlugin)
