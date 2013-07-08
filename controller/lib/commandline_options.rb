# encoding: utf-8
require 'ostruct'
require 'optparse'

def parse_arguments

  OptionParser.new do |opts|
    opts.banner = 'implement banner \n'
    opts.on('-p', '--path [String]', 'set pwd to this path (should point to run)') do |path|
      Dir.chdir path
    end
    opts.on_tail('-h', '--help', 'Show this message') do
       puts opts
       exit
    end

  end.parse!
end
