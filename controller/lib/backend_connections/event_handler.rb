module Schem
  class ThreadedEventHandler
    def initialize(&callback)
      @queue = Queue.new
      @runner = Thread.new do
        loop do
          callback.call(@queue.pop)
        end
      end
    end

    def push(msg)
      @queue.push(msg)
    end

    def stop
      @runner.kill
    end

  end
end
