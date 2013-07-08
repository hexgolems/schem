# encoding: utf-8
require_relative './msg.rb'
require_relative './result_list.rb'
require 'whittle'
require 'pp'

module Schem

# This class contains the method #parse inherited from Parser that can be used to parse a single
# output line from gdb. This line may not contain '\n' and has to be striped
# (e.g. no whitespaces at the begin or end of line)
  class MIOutputParser < Whittle::Parser

    rule(',')
    rule('=')
    rule('*')
    rule('+')
    rule('~')
    rule('@')
    rule('&')
    rule('{')
    rule('}')
    rule('[')
    rule(']')
    rule('^')
    rule('(gdb)')

    rule(token_num: /[0-9]+/)
    rule(word:  /[\w\-]+/).as { |w| w }
    string_regexp = /"([^"\\]|\\.)*"/
    rule(cstring: string_regexp).as { |string| string[1..-2] }

    rule(:async_type) do |r|
      r['=']
      r['*']
      r['+']
    end

    rule(:stream_type) do |r|
      r['&']
      r['~']
      r['@']
    end

    rule(:results) do |r|
      r[:result].as { |e| e }
      r[:result, ',', :results].as { |e, _, l| l.merge(e) }
    end

    # why use ResultList not []? because gdb mi things that [foo=3, foo=4] is a
    # valid list, thats why
    rule(:list_results) do |r|
      r[:result].as { |e| ResultList.new(e) }
      r[:result, ',', :list_results].as { |e, _, l|  ResultList.new(l).merge!(e) }
    end

    rule(:result) do |r|
      r[:string, '=', :value].as { |n, _, v| { n => v }  }
    end

    rule(:values) do |r|
      r[:value].as { |v| [v] }
      r[:value, ',', :values].as { |v, _, l| [v] + l }
    end

    rule(:value) do |r|
      r[:cstring].as { |w| w }
      r[:tupel].as { |w| w }
      r[:list].as { |w| w }
    end

    rule(:string) do |r|
      r[:token_num]
      r[:word]
    end

    rule(:list) do |r|
      r['[', ']'].as { [] }
      r['[', :values, ']'].as { |_, v, _| v }
      r['[', :list_results, ']'].as { |_, v, _| v }
    end

    rule(:tupel) do |r|
      r['{', '}'].as { {} }
      r['{', :results, '}'].as { |_, v, _| v }
    end

    rule(:record) do |r|
      r['^', :string].as { |_, type| Schem::Msg.new('record', type, '') }
      r['^', :string, ',', :results].as { |_, type, _, results| Schem::Msg.new('record', type, results) }
      r['^', :string, ',', :cstring].as { |_, type, _, string| Schem::Msg.new('record', type, string) }
    end

    rule(:async) do |r|
      r[:async_type, :string, ',', :results].as { |type, name, _, result| Schem::Msg.new('async', type, name, result) }
      r[:async_type, :string].as { |type, name| Schem::Msg.new('async', type, name, nil) }
    end

    rule(:stream) do |r|
      r[:stream_type, ',', :cstring].as { |type, _, string| Schem::Msg.new('stream', type, string)  }
      r[:stream_type, :cstring].as {  |type, string| Schem::Msg.new('stream', type, string) }
    end

    rule(:token) do |r|
      r[].as { nil }
      r[:token_num].as { |w| w.to_i }
    end

    rule(:start) do |r|
      r[:token, :record].as do |token, record|
        record.token=token
        record
      end

      r[:stream]

      r[:token, :async].as do |token, async|
        async.token=token
        async
      end

      r['(gdb)'].as { nil }
    end

    start(:start)
  end
end
