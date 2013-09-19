require 'eventmachine'
require 'em-websocket'
require 'em-http-server'

module Schem

  class HTTPHandler < EM::HttpServer::Server

      def read_file(url)
        prefix = File.expand_path(DbgConfig.webserver.www_root)
        path = File.expand_path(prefix + url)
        if path.index(prefix) == 0 && File.exists?(path)
          return ::IO.read(path)
        else
          return nil
        end
      end

      def process_http_request
            url =   @http_request_uri
            url = '/interface.html' if url == '/'
            Log.dbg('web:http',"request to: #{url.inspect}")
            response = EM::DelegatedHttpResponse.new(self)
            response.content = read_file(url)
            if response.content
              response.status = 200
#             response.content_type 'text/html'
              response.send_response
            else
              response.status = 403
              response.send_response
            end
      end

      def http_request_errback e
        # printing the whole exception
        puts e.inspect
      end

  end

  class WebServer

    attr_accessor :plugin_manager
    def run_websocket
      EM::WebSocket.run(:host => "127.0.0.1", :port => 8001) do |ws|
        ws.onopen { |handshake|
          path =  handshake.path.split('/').select { |str| str.length > 0 }
          if path[0] == 'spawn_plugin'
            if @plugin_manager.run_web(path[1], ws)
              #Log.info('web:sock',"spawned plugin #{path.inspect}")
              ws.send 'ok'
            else
              #Log.info('web:sock',"no such plugin found: #{path.inspect}")
              ws.send "plugin not found"
              ws.close
            end
          end
        }

#ws.onclose { puts "Connection closed" }

# ws.onmessage { |msg| puts "Recieved message: #{msg}"; ws.send "Pong: #{msg}" }
      end
    end

    def run_http
      EM::start_server("127.0.0.1", 8000, HTTPHandler)
    end

    def initialize(plugin_manager)
      @plugin_manager = plugin_manager
      EM.run do
        run_websocket
        run_http
      end
    end
  end
end
