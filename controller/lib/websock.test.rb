# encoding: utf-8
require_relative './webserver/webserver.rb'

serv = Dbg::WebServer.new('127.0.0.1', 8000)
loop do
  sleep 1000
end
