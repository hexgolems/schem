# encoding: utf-8
require_relative './dependencies.rb'
require_relative './logger/logger.rb'

require 'erb'

def assert(desc = nil, &block)
  fail "assertion failed #{desc}\n #{Kernel.caller}" unless block.call
end

def deep_copy(o)
  Marshal.load(Marshal.dump(o))
end

class Hash
  def map_keys(&block)
    each_pair.reduce({}) { |h, (key, val)| new_key = block.call(key, val); h[new_key] = val; h }
  end

  def map_values(&block)
    each_pair.reduce({}) { |h, (key, val)| h[key] = block.call(key, val); h }
  end

  def map_pairs(&block)
    each_pair.reduce({}) { |h, (key, val)| new_key, new_val = block.call(key, val); h[new_key] = new_val; h }
  end

  def flatten_hash
    res = {}
    each_pair do |key, val|
      if val.is_a? Hash
        res.merge! val.flatten_hash
      else
        res[key] = val
      end
    end
    res
  end
end

def in_pry_mutex(&block)
  @pry_mutex ||= Mutex.new
  to_join = nil
  @pry_mutex.synchronize do
    $pry_thread ||= nil
    $pry_thread.kill if $pry_thread
    $pry_thread = Thread.new do
      puts ''
      block.call
    end
    to_join = $pry_thread
  end
  to_join.join
end

class Pry
  def self.rescue_in_pry(&block)
    with_warnings(nil) do
      # this kept on crashing(!) the ruby vm therefore it is disabled with && false
      if self.respond_to?(:rescue) && false
        self.rescue do
          begin
            with_warnings(true) do
              block.call
            end
            rescue => e
              in_pry_mutex do
                rescued(e)
              end
          end
        end
      else
        puts 'For advanced error handleing please install the pry-rescue gem'
        with_warnings(true) do
          block.call
        end
      end
    end
  end
end

class Binding
  def dbg
    puts 'spawning pry1'
    in_pry_mutex { puts 'spawning pry'; pry }
  end
end

class AnyOf
  attr_accessor :args
  def initialize(args)
    @args = args
  end
end

class Range
  def intersection(rangeb)
    assert { rangeb.class == Range }
    assert { rangeb.min }
    res = ([min, rangeb.min].max .. [max, rangeb.max].min)
    return nil if res.first > res.last
    res
  end

  def contains_range?(rangeb)
    min <= rangeb.min && max >= rangeb.max
  end

  def hex_inspect
    "(#{min.to_s(16)}..#{max.to_s(16)})"
  end

  def size
    max - min + 1
  end unless (0..1).respond_to? :size
end

class Class
  def any_of(*args)
    AnyOf.new(args)
  end

  def attr_assert(name, *args, &block)
    attr_reader name
    attr_assert_writer(name, *args, &block)
  end

  def attr_assert_writer(name, *args, &block)
    assert { args.length <= 1 }
    assert { !block || args.length == 0 } # if block then args.length == 0
    assert { block || args.length == 1 } # if !block then args.length == 1

    test = block
    if args.length == 1
      if args[0].is_a? AnyOf
        possible_values = args[0].args
        test = lambda { |val| assert { possible_values.include? val }; true }
      else
        test = lambda { |val| assert { args[0] === val }; true }
      end
    end

    define_method("#{name}=") do |value|
      if test.call(value)
        instance_variable_set("@#{name}", value)
      else
        fail ArgumentError.new("Invalid argument #{value} for #{name}")
      end
    end
  end
end

def surround(path = 'include:surround', info, &block)
  startt = Time.now
  from = Schem::Log.get_call_stack[1..2].join(' from ')
  Schem::Log.dbg(path + ':begin', from, info)
  begin
    block.call
  ensure
    endt = Time.now
    from = Schem::Log.get_call_stack[1..2].join(' from ')
    Schem::Log.dbg(path + ':done', from, info + "took #{(endt - startt)} sec")
  end
end

def max_tries(num = 3, _sleep = 0, path = 'include:max_tries', &block)
  tries = 0
  begin
    return block.call
  rescue => e
    tries += 1
    if tries < num
      Schem::Log.error(path + ':try_failed', "tries failed (#{tries}/#{num})\n" + Schem::Log.trace(e))
      retry
    else
      raise e
    end
  end
end

class Numeric
  def to_gdbi
    self
  end

  def hex_dump(digits = nil)
    return to_s(16).rjust(digits, '0') if digits
    to_s(16)
  end

  def to_gdbs(base = 10)
    case base
    when 16 then return '0x' + to_s(16)
    when 10 then return to_s(10)
    when 8 then return '0' + to_s(8)
    else fail "unknown base #{base.inspect} for gdbi"
    end
  end
end

class String
  def self.byte_repr(chr, default = '·')
    case chr
    when  /[[:graph:]]/ then Schem::Esc.h(chr)
    when "\n" then  '↵'
    when ' ' then  '␣'
    when "\t" then  '⇥'
    when "\0" then  '␀'
    else default
    end
  end

  def to_gdbi
    return to_i(16) if self[0..1] == '0x'
    return to_i(16) if self[-1] == 'h'
    return to_i(8) if self[0] == '0'
    return self[0..-2].to_i(10) if self[-1] == '.'
    return to_i(10) if is_gdbi?
    nil
  end

  def to_gdbs(_base = 10)
    fail "not a gdbi #{inspect}" unless is_gdbi?
    to_gdbi.to_gdbs(base64)
  end

  def is_gdbi?
    self =~ /^[ ]*[0-9]+(\.)?[ ]*$/ || self =~ /^[ ]*0x[0-9A-Fa-f]*[ ]*$/
  end

  def ellipsis(len)
    res = if length > len then
            self[0..len - 2] + '…'
    else
      self
    end
    res
  end

  def hover_ellipsis(len)
    "<span title=\"#{Schem::Esc.h(self)}\">#{Schem::Esc.h(ellipsis(len))}</span>"
  end

  def hex_dump
    bytes.map { |x| x.hex_dump(2) }.join(' ')
  end
end

module Kernel
  def silence_warnings
    with_warnings(nil) { yield }
  end

  def with_warnings(flag)
    old_verbose, $VERBOSE = $VERBOSE, flag
    yield
  ensure
    $VERBOSE = old_verbose
  end
end unless Kernel.respond_to? :silence_warnings

module Schem
  module Esc
    def self.h(x)
      x = x.dup
      x.gsub!('&', '&amp')
      { '>' => '&gt;', '<' => '&lt;', '"' => '&quot;', "'" => '&#39;' }.each_pair do |k, v|
        x.gsub!(k, v)
      end
      x
    end
  end
end
