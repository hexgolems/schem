require 'ostruct'

# TODO document me
class BaseService


  attr_accessor :is_initialized
  attr_reader :invalidation_counter

  def initialize(controller)
    @invalidation_counter = 0
    @waiting = Set.new
    @published_values = {}
    @values = {}
    @controller = controller
    @redis = @controller.new_redis_connection
  end

  def srv
    @controller.service_manager.service_finder
  end

  def invalidate
    raise 'Do not modify service in ensure block' if Thread.current[:is_inside_ensure_consistency] == true
    @invalidation_counter += 1
  end

  def update(reason)
    invalidate
    signal_waiting(reason)
  end

  def signal_waiting(*reason_args)
    @waiting.each do |channel|
      reason = OpenStruct.new(*reason_args)
      channel.send reason
      reason.service = self
    end
  end

  def register_waiting(channel)
    @waiting.add(channel)
  end

  def deregister_waiting(channel)
    @waiting.delete(channel)
  end

  def publish(name, &block)
    @published_values[name] = Thread.delay(&block)
  end

  def get_published_value(name)
    return @published_values[name].value
  end

  def method_missing(name, *args, &block)
    super unless @published_values.include? name
    return get_published_value(name)
  end

  def respond_to_missing?(name, *args, &block)
    return @published_values[name] || super
  end

end
