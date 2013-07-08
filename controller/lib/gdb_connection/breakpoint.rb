# encoding: utf-8
require_relative './include.rb'

class Breakpoint

attr_accessor :number, :type, :disp, :enabled, :addr, :at, :thread_groups,
              :times, :orgiginal_location, :func, :file, :fullname, :line,
              :cond, :ignore, :what

# rubocop:disable MethodLength
    def initialize(res)
        @number = res['number']
        @type = res['type']
        @disp = res['disp']
        @enable = res['enable'] == 'y'
        @addr = res['addr']
        @at = res['at']
        @thread_groups = res['thread-groups']
        @times = res['times']
        @original_location = res['original_location']
        @func = res['func']
        @file = res['file']
        @fullname = res['fullname']
        @line = res['line']
        @cond = res['cond']
        @ignore = res['ignore']
        @what = res['what']
    end
# rubocop:enable MethodLength
end
