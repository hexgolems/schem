# encoding: utf-8
require 'reel'

module Schem
  class WebServer < Reel::Server

    attr_accessor :plugin_manager

    def initialize(host = DbgConfig.webserver.interface, port = DbgConfig.webserver.port)
      super(host, port, &method(:on_connection))
    end

    def on_connection(connection)
      while request = connection.request
        case request
        when Reel::Request
          handle_request(request)
        when Reel::WebSocket
          handle_websocket(request)
        end
      end
    end

    def read_file(url)
      prefix = File.expand_path(DbgConfig.webserver.www_root)
      path = File.expand_path(prefix + url)
      if path.index(prefix) == 0 && File.exists?(path)
        return ::IO.read(path)
      else
        return nil
      end
    end

    def handle_request(request)
        url = request.url
        Log.dbg('web:http',"request to: #{url.inspect}")
        url = '/interface.html' if url == '/'
        content = read_file(url)
        if content
          request.respond :ok, content
        else
          request.respond :forbidden
        end
    end

    def handle_websocket(sock)
      sleep 0.5 until @plugin_manager
      path =  sock.url.split('/').select { |str| str.length > 0 }
      if path[0] == 'spawn_plugin'
        if @plugin_manager.run_web(path[1], sock)
          Log.info('web:sock',"spawned plugin #{path.inspect}")
          sock << 'ok'
        else
          Log.info('web:sock',"no such plugin found: #{path.inspect}")
          sock << "plugin not found"
          sock.close
        end
      end
    end
  end
end
