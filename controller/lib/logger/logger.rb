# encoding: utf-8
require 'English'
require 'pry'

module Schem
  class DefaultFormater
    def format(type, path, string, loc)
      string =  ('=' * 80) + "\n" + string + "\n" + ('=' * 80) if string =~ /[\n\r]/
      "[#{type}:#{path} #{loc} #{Time.now.strftime('%a,%d.%b: %H:%M:%S:%L')}] --\n#{string}"
    end
  end

  class ColorFormater
    def format(type, path, string, loc)
      case type
      when :error, :critical then
        type = type.to_s.red
        path = path.red
        loc = loc.red
      when :info then type = type.to_s.green
      when :out, :dbg then
      end
      string =  ('=' * 80) + "\n" + string + "\n" + ('=' * 80) if string =~ /[\n\r]/
      time = Time.now.strftime('%a,%d.%b: %H:%M:%S:%L').grey
      header = '['.grey + type.to_s.grey + ':' + path + ', ' + loc.grey + ', ' + time + '] --'.grey + "\n"
      content = " #{string}"
      header + content
    end
  end

  class Sink
    def initialize(io, filters = [//], formater = DefaultFormater.new)
      @io, @formater = io, formater
      @filters = filters
    end

    def puts(type, path, string, loc)
      if @filters.length == 0 || @filters.any? { |f| path =~ f }
        string = @formater.format(type, path, string, loc)
        @io.puts(string)
      end
    end
  end

  class SchemLog
    class AquireStackException < Exception
    end

    def initialize
      @sinks = {}
    end

    def get_call_stack
      fail AquireStackException.new
    rescue AquireStackException => e
      return e.backtrace
    end

    def add(type, io, *args)
      kw_error = "please give keyword arguments only got #{args.inspect}, expected Hash"
      fail kw_error if args.length > 1
      fail kw_error if args.length == 1 && !args[0].is_a?(Hash)
      args = { filter: [], formater: DefaultFormater.new }.merge(args[0] || {})
      @sinks[type] ||= Set.new
      @sinks[type].add Sink.new(io, args[:filter], args[:formater])
    end

    def log(type, path, string, loc)
      loc = get_call_stack[3] unless loc
      base_path = File.expand_path('../') + '/'
      loc.gsub!(base_path, '')
      @sinks[type].each  do |sink|
        sink.puts(type, path, string, loc)
      end
    end

    def out(path = '', loc = nil, string)
      log(:out, path, string, loc)
    end

    def dbg(path = '', loc = nil, string)
      log(:dbg, path, string, loc)
    end

    def info(path = '', loc = nil,  string)
      log(:info, path, string, loc)
    end

    def error(path = '', loc = nil, string)
      log(:error, path, string, loc)
    end

    def critical(path = '', loc = nil, string)
      log(:critical, path, string, loc)
      exit
    end

    def trace(exception = nil)
      if !exception
        "#{$ERROR_INFO}\n#{$ERROR_POSITION.join("\n")}"
      else
        "#{exception.message} (#{exception.class})\n" + exception.backtrace.join("\n")
      end
    end
  end

  Log = SchemLog.new

  def self.init_logger
    cf = ColorFormater.new
    # Log.add(:out, $stdout, formater: cf)
    Log.add(:out, File.open('log/gdb.out.log', 'w'), filter: [/gdb:mi:(send|recv)/])
    Log.add(:dbg, $stdout, formater: cf)
    Log.add(:info, $stdout, formater: cf)
    Log.add(:error, $stderr, formater: cf)
    Log.add(:critical, $stderr, formater: cf)
    Log.add(:override_puts, $stderr, formater: cf)
  end
end
