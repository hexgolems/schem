# encoding: utf-8
module Schem

# This class represents a message used for communication. It may be used in different situations:
# *It may represents a message send to the gdb wrapper
# *It may represents a message answered from the gdb wrapper to the multiplexer
# *It may represent a message passed from the client to gdb (via the multiplexer)
# *It may rperesent a meta message send from the client to the multiplexer (such as hallo or hook)

  class Msg
    attr_accessor :msg_type # mi, record, async, stream, ipc, meta
    attr_accessor :content_type # exec, status, notify, consol, log, target
    attr_accessor :token # numeric
    attr_accessor :value # value may be any json compilant structure such as hash/array fixnum etc

    # @return [Array] A structur [token, msg_type, content_type, value] that can be converted into a json string
    def to_json_struct
      [@token, @msg_type, @content_type, @value]
    end

# creates a register message. Register messages are meta messages used to assign a new name to a client
# @param [String] name the name of the client
# @return [Schem::Msg] the register message
    def self.register(name)
      self.new('meta', 'hallo', { 'name' => name }, nil)
    end

# creates a hook message. Hook messages are meta messages send from the client
# to the multiplexer and will result in creation of a hook.
# after registering a hook for the given type, all stream or async messages
# from gdb with the content_type = type will be forwardet to the client.
# @return [Schem::Msg] the hook message used to aquire a hook for the given stream/async message type.
# @param [String] type the type of the async/stream messages that are being hooked
    def self.hook(type)
      self.new('meta', 'hook', { 'type' => type }, nil)
    end

# creates a new Msg from the json struct.
# @param [Array] json_struct the json struct as returned by to_json_struct
# @return [Schem::Msg] the Message constructed from the json_struct
    def self.from_json_struct(json_struct)
      typecheck(json_struct, Array)
      token, msg_type, content_type, value = json_struct
      typecheck(token, Fixnum, String)
      typecheck(msg_type, String)
      typecheck(content_type, String)
      self.new(msg_type, content_type, value, token)
    end

# constructor
# @param [String] msg_type the type of the message (such as "mi", "meta" etc.)
# @param [String] content_type the type of the conntent of the message (such as
# "hallo" or "hook"). The content_type may be [*+=~@&] wich are mapped to exec,
# status, notify, console, target, log respectively.
# @param [Json] value the accutall content of the message, anything that can be
# serialized with json
# @param [Fixnum] token an id of the message (used to assign returns)
    def initialize(msg_type, content_type, value, token = nil)
      @msg_type, @value, @token = msg_type, value, token
      @content_type = case content_type
                      when '*' then 'exec'
                      when '+' then 'status'
                      when '=' then 'notify'
                      when '~' then 'console'
                      when '@' then 'target'
                      when '&' then 'log'
                      else content_type
                      end
    end
  end
end
