# encoding: utf-8

require 'manual_parser_optimized.rb'
require_relative './prettyshow.rb'
require_relative './breakpoint.rb'
require_relative '../include.rb'
require_relative './pin_api.rb'
require_relative './event_handler.rb'

silence_warnings do
  require 'rubygems'
  require 'thread'
  require 'thread/promise'
  require 'set'
  require 'pp'
  require 'pty'
  require 'English'
  require 'thread/promise'
  require 'monitor'

  require 'spoon' if RUBY_ENGINE == 'jruby'
end

module Schem
  # This class will wrap a running gdb instance and provides an scriptable interface to the gdb instance.
  class PINWrapper
    include MonitorMixin
    include PinDebuggerApi
    attr_accessor :pin, :stream, :async, :records, :verbose, :debug
    attr_reader :breakpoints

    # rubocop:disable MethodLength
    # Creates a new GDB::Wrapper that connects to process-id and
    # executable.
    def initialize(executable, _pid = '', _verbose = false)
      super()
      init_members
      init_pin(executable)
      init_pin_server(executable)

      @debugger = self # used by gdb_api
      init_dbg_api

      #       trap("CLD") do
      #         pid = nil
      #         begin
      #           pid = Process.wait
      #           if pid == @gdb_status.pid
      #             Log.critical("gdb died")
      #           elsif pid == @gdbserver_status.pid
      #             Log.critical("gdbserver died")
      #           end
      #         rescue Errno::ECHILD
      #           Log.error("gbd:subproc","got ECHILD Exception while wait")
      #         rescue Exception => e
      #           Log.error("gbd:subproc","got Exception while wait",Log.trace(e))
      #         end
      #       end
    end

    def init_members
      @token = 0
      @stream = Queue.new
      @async = Queue.new
      @records = Queue.new
      @parser = ManualParser.new
      @error = File.open('error.log', 'a')
      @debug = verbose
      @breakpoints = {}
      @promises = {}
      @event_handlers = {}
      @port = nil
      %w(exec status notify console target log gdb stream).each do |type|
        @event_handlers[type] = Set.new
      end
    end

    def init_pin(executable)
      # mi2 = The current gdb/mi interface.
      # nx = Do not execute commands from any `.gdbinit' initialization files.
      # q = ``Quiet''.   Do not print the introductory and copyright
      # messages. These messages are also suppressed in batch mode.
      @pin = IO.popen("gdb --interpreter mi2 -q -nx #{executable} 2>&1", 'r+')
      @pin_status = $CHILD_STATUS

      @runner = Thread.new do
        loop { runner }
      end
    end

    def restart
      terminate_server
      spawn_server
    end

    def spawn_server
      cmd = "../..//pint/pin/pin -injection child -appdebug -t ./own_gdb_cmds.so -- #{@executable}"
      master, slave = PTY.open
      pid = spawn(cmd, in: slave, out: slave)
      loop do
        output = master.gets
        match = output.match(/(?<port>[0-9]+)/)
        @port = match['port'].to_i if match
        break if @port
      end
      system("urxvt -pty-fd #{master.fileno}&")
      slave.puts send_mi_string("-target-select remote 127.0.0.1:#{@port}").content_type
    end

    def init_pin_server(executable)
      # TODO ensure that send_mi_string termiantes if gdbserver is dead
      # TODO also ensure that the user notices when gdbserver is dead
      @executable = executable
      spawn_server
      send_mi_string('-gdb-set target-async on')
    end

    def terminate_server
      send_mi_string('-interpreter-exec console "kill"')
      @promises.each do |promise|
        promise.deliver(nil)
      end
      @promises.clear
    end

    # rubocop:enable MethodLength
    def register_event_handler(*types, handler)
      synchronize do
        types.each do |type|
          @event_handlers[type] << handler
        end
        return handler
      end
    end

    def remove_event_handler(*types, handler)
      synchronize do
        types.each do |type|
          @event_handlers[type].delete handler
        end
      end
    end

    # rubocop:disable MethodLength
    # Will be called continously from the runner thread and handles the output from gdb.
    # Will parse the outputline from gdb and call handle_output with the parsed result as Schem::Msg
    def runner
      line = @pin.gets
      if line
        Log.out('pin:mi:recv', line)
        begin
          # ok this looks ABSOLUTLY wrong, but in some cases GDB attaches a literal "\\n" to the end of the string
          # we have to remove this to make the line become a valid GDB interface line XXX TODO FIXME FUCKUP
          # that .chomp('\n') is a workaround for a confirmed gdb mi bug, should be obsolete in the future
          val = @parser.parse(line.strip.chomp('\n'))
        # Log.out("gdb:mi:output:"+val.inspect,line)
      rescue
        Log.error('pin:parsing:exception', "In #{line.inspect}\n #{Log.trace}")
        val = nil
        end
        Log.out('pin:mi:output:val', val.inspect)
        handle_output(val)
      end
    end
    # rubocop:enable MethodLength

    # Will return a new unique number in a threadsafe manner. This number can be used as token for messages to gdb
    def get_new_token
      synchronize do
        @token += 1
        token = @token
        return token
      end
    end

    # rubocop:disable MethodLength
    # This function takes the parsed output of gdb and ensure that all promises
    # are delivered. It will also pass events to registered event handlers
    # @param [Schem::Msg] msg
    def handle_output(msg)
      synchronize do
        return unless msg
        if msg.msg_type == 'record' && msg.token && @promises.include?(msg.token)
          promise = @promises[msg.token]
          if promise
            @promises.delete msg.token
            promise.deliver(msg)
          end
        end

        if @event_handlers.include? msg.content_type
          @event_handlers[msg.content_type].each do |handler|
            handler.push(msg)
          end
        end
      end
    end
    # rubocop:disable MethodLength

    # @param [String] mi_instr The string that is send to gdb
    # @param [Proc] callback the function that is called when the answer is recieved
    # Will send a mi instruction to the gdb instance and registers a callback that
    # is executed once upon recieving the answer to the instruction.
    # Note: all callbacks are called from within the runner thread. Therefor every
    # callback has to terminate. And should not be computationally intensice
    def send_mi_string(mi_instr, blocking = true, timeout = nil, &callback)
      promise = nil
      synchronize do
        fail 'dont give a callback' if callback
        token = get_new_token
        promise = send_mi_nonblocking(token, mi_instr)
        return promise unless blocking
      end
      answer = promise.value(timeout)
      answer
    end

    def send_pin_string(mi_instr, _regex = //, timeout = nil)
      future, handler = nil, nil
      synchronize do
        captured, capturing = '', false
        future = Thread.promise
        pintoken = ((Time.now.to_f * 10_000_000).to_i) % 65_535
        handler = ThreadedEventHandler.new do |msg|
          if msg.value =~ /\A#{pintoken}/
            future.deliver msg.value[pintoken.to_s.length..-1]
          end
        end
        register_event_handler('target', handler)
        instr = "-interpreter-exec console \"#{mi_instr} @ #{pintoken}\""
        Log.out('pin:mi:send', "#{instr}")
        @pin.puts(instr)
      end
      res = future.value(timeout)
      remove_event_handler('target', handler)
      handler.stop
      res
    end

    def send_cli_string(mi_instr, regex = //, timeout = nil)
      future, handler = nil, nil
      synchronize do
        captured, capturing = '', false
        future = Thread.promise
        handler = ThreadedEventHandler.new do |msg|
          capturing = true if msg.value =~ regex
          future.deliver captured if capturing && msg.value =~ /\Adone\Z/
          captured += msg.value if capturing
        end
        register_event_handler('console', 'gdb', handler)
        instr = "-interpreter-exec console \"#{mi_instr}\""
        Log.out('pin:mi:send', "#{instr}")
        @pin.puts(instr)
      end
      res = future.value(timeout)
      remove_event_handler('console', 'gdb', handler)
      handler.stop
      res
    end

    def send_mi_nonblocking(token, mi_instr)
      synchronize do
        promise = Thread.promise
        @promises[token] = promise
        Log.out('pin:mi:send', "#{token}#{mi_instr}")
        @pin.puts(token.to_s + mi_instr)
        return promise
      end
    end
  end # end of class server
end # end of namespace Schem
