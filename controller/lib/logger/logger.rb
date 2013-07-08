module Schem

  class DefaultFormater
    def format(type,path,string)
        if string =~/[\n\r]/
          string= "\n"+("="*80)+"\n"+string+"\n"+("="*80)
        end
      "[#{type}:#{path} #{Time.now.strftime("%a,%d.%b: %H:%M:%S:%L")}] -- #{string}"
    end
  end

  class Sink
    def initialize(io, filters=[//],formater=DefaultFormater.new)
      @io,@formater = io, formater
      @filters = filters
    end

    def puts(type,path,string)
      if @filters.length == 0 || @filters.any?{|f| path =~ f }
        string = @formater.format(type,path,string)
        @io.puts(string)
      end
    end
  end

  class SchemLog

    def initialize()
      @sinks = {}
    end

    def add(type, io, *filter)
      @sinks[type]||=Set.new
      @sinks[type].add Sink.new(io,filter)
    end

    def log(type,path,string)
      @sinks[type].each  { |sink| sink.puts(type,path,string) }
    end

    def out(path = "", string)
      log(:out,path,string)
    end

    def dbg(path = "", string)
      log(:dbg,path,string)
    end

    def info(path = "", string)
      log(:info,path,string)
    end

    def error(path = "", string)
      log(:error,path,string)
    end

    def critical(path = "", string)
      log(:critical,path,string)
      exit
    end

    def trace()
      "#{$!}\n#{$@.join("\n")}"
    end

  end

  Log = SchemLog.new

  def self.init_logger()
    Log.add(:out, File.open("log/gdb.out.log","a") )
    Log.add(:dbg, $stdout)
    Log.add(:info, $stdout)
    Log.add(:error, $stderr)
    Log.add(:critical, $stderr)
    Log.add(:dbg, $stdout, /cpuview/)
  end

end
