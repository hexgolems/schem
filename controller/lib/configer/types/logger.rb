# encoding: utf-8
require_relative '../configer.rb'
require 'logger'

class Logger
  def self.to_config_s(val)
    val.instance_variable_get(:@logdev).filename
  end

  def self.from_config_s(filename)
    return Logger.new(filename)
  end
end

class LogLevel

  include Configer::Dummy

  def self.levels
    %w[DEBUG INFO WARN ERROR FATAL UNKNOWN]
  end

  def self.to_config_s(val)
    case val
    when (0..levels.length)
      levels[val]
    else
      val
    end
  end

  def self.from_config_s(val)
    begin
      return Logger.const_get(val) if levels.include? val
    rescue NameError
      return Logger::DEBUG
    end
    return val.to_i
  end
end
