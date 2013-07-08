# encoding: utf-8
require 'rubygems'
require 'thread'
require 'set'
require 'pp'
require 'pty'
require 'English'
require 'celluloid/io'

require_relative './MIOutputParser.rb'
require_relative './prettyshow.rb'

module Schem

  # This class will wrap a running gdb instance and provides an scriptable interface to the gdb instance.
  class GDBWrapper

    attr_accessor :gdb, :stream, :async, :records, :verbose, :debug
    attr_reader :breakpoints

    # rubocop:disable MethodLength
    # Creates a new GDB::Wrapper that connects to process-id and
    # executable.
    def initialize(executable, pid = '', verbose = false)
        # mi2 = The current gdb/mi interface.
        # nx = Do not execute commands from any `.gdbinit' initialization files.
        # q = ``Quiet''.   Do not print the introductory and copyright
        # messages. These messages are also suppressed in batch mode.
        fork do
            Process.daemon
            Process.exec('gdbserver', ':12345', executable)
        end
        @gdb = IO.popen("gdb --interpreter mi2 -q -nx #{executable} #{pid} 2>&1", 'r+')
        @token = 0
        @stream = Queue.new
        @async = Queue.new
        @records = Queue.new
        @parser = MIOutputParser.new
        @error = File.open('error.log', 'a')
        @debug = verbose
        @token_mutex = Mutex.new

        @breakpoints = {}
        @callbacks = {}

        %w{exec status notify console target log}.each do |type|
          @callbacks[type] = Set.new
        end

        @runner = Thread.new do
          loop do
            runner
          end
        end

        send_mi_string('-target-select remote 127.0.0.1:12345')
        send_mi_string('-gdb-set target-async on')
        send_mi_string('-gdb-set disassembly-flavor intel')
    end
# rubocop:enable MethodLength

# @param [String] type the message content_type for which the hooks should be installed
# @param [Proc] callback the function that should be called uppon recieving a message of the given content_type
# Will install a callback for all messages with the given content_type
# Note: all callbacks are called from within the runner thread. Therefor every
# callback has to terminate. And should not be computationally intensice
    def register_type_hook(*types, &callback)
      types.each do |type|
        @callbacks[type] << callback
      end
      return callback
    end

# @param [String] type the message content_type for which the hooks was installed
# @param [Proc] callback the function that should have been called uppon recieving a message of the given content_type
# Will remove a single callback
    def remove_type_hook(type, callback)
      @callbacks[type].delete callback
    end

# rubocop:disable MethodLength
# Will be called continously from the runner thread and handles the output from gdb.
# Will parse the outputline from gdb and call handle_output with the parsed result as Schem::Msg
    def runner
      line = @gdb.gets
      if line
        Log.out("gdb:mi:output",line)
        begin
            # ok this looks ABSOLUTLY wrong, but in some cases GDB attaches a literal "\\n" to the end of the string
            # we have to remove this to make the line become a valid GDB interface line XXX TODO FIXME FUCKUP
            # that .chomp('\n') is a workaround for a confirmed gdb mi bug, should be obsolete in the future
            val = @parser.parse(line.strip.chomp('\n'))
        rescue
            Log.error("gdb:parsing:exception","In #{line.inspect}\n #{Log.trace}")
            val = nil
        end
        handle_output(val)
      end
    end
# rubocop:enable MethodLength

# Will return a new unique number in a threadsafe manner. This number can be used as token for messages to gdb
    def get_new_token
      token = 0
      @token_mutex.synchronize do
        @token += 1
        token = @token
      end
      return token
    end

# rubocop:disable MethodLength
# This function takes the parsed output of gdb and ensure that all callbacks
# are called. If the callbacks are one-time callbacks (e.G. a callback that
# were registered for a single message token to recieve the answer) the are
# also removed after the execution.
# Note: all callbacks are called from within the runner thread. Therefor every
# callback has to terminate. And should not be computationally intensice
# @param [Schem::Msg] msg
    def handle_output(msg)
      return unless msg
      if msg.msg_type  ==  'record' && msg.token && @callbacks.include?(msg.token)
        callback = @callbacks[msg.token]
        if callback
          @callbacks.delete msg.token
          save_call(callback, msg)
        end
      end

      if @callbacks.include? msg.content_type
        @callbacks[msg.content_type].each do |callback|
          msg.token = msg.content_type
          save_call(callback, msg)
        end
      end
    end
# rubocop:disable MethodLength

    def save_call(callback, args)
      return unless callback
      begin
        callback.call(args)
      rescue
        Log.error("gdb:callback:exception","#{callback} (#{args.inspect})\n #{Log.trace}")
      end
    end

# @param [String] mi_instr The string that is send to gdb
# @param [Proc] callback the function that is called when the answer is recieved
# Will send a mi instruction to the gdb instance and registers a callback that
# is executed once upon recieving the answer to the instruction.
# Note: all callbacks are called from within the runner thread. Therefor every
# callback has to terminate. And should not be computationally intensice
    def send_mi_string(mi_instr, timeout = nil, &callback)
      token = get_new_token
      Log.out("gdb:mi:input","#{token}#{mi_instr}")
      if callback
        return send_mi_nonblocking(token, mi_instr, &callback)
      else
        return send_mi_blocking(token, mi_instr, timeout)
      end
    end

    # wrapps an object for use as Future result
    class ValueWrapper
      attr_accessor :value
      def initialize(value)
        @value = value
      end
    end

    def send_mi_blocking(token, mi_instr, timeout = nil)
        future = Celluloid::Future.new
        @callbacks[token] = lambda { |*args| future.signal(ValueWrapper.new(args)) }
        @gdb.puts(token.to_s + mi_instr)
        return future.value(timeout)
    end

    def send_mi_nonblocking(token, mi_str, &callback)
        @callbacks[token] = callback
        @gdb.puts(token.to_s + mi_instr)
        return token
    end

  end # end of class server
end# end of namespace Schem
