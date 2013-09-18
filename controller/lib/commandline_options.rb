# encoding: utf-8
require 'ostruct'
require 'optparse'
require 'pry'

def parse_arguments
  options = OpenStruct.new

  OptionParser.new do |opts|

    opts.banner = 'implement banner \n'

    opts.on('-b', '--backend [String]', 'set this to either gdb or pin (for now)') do |backend|
      options.backend = backend
    end

    opts.on('-p', '--path [String]', 'set pwd to this path (should point to run)') do |path|
      Dir.chdir path
    end

    opts.on_tail('-h', '--help', 'Show this message') do
       puts opts
       exit
    end

  end.parse!

  return options

end
