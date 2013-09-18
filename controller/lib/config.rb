# encoding: utf-8
require_relative './configer/configer.rb'
class DbgConfig < Configer::Template

  # where to expect the config file
  config_path 'config/dbg.conf'

  # we wil not write back changes to the config structure to the file
  auto_write false

  value name: 'controller' do
    value name: 'debug_with_pry', default: true, docu: 'set to true to caputre exceptions using the pry-rescue gem'
  end

  value name: 'webserver' do
    value name: 'www_root', type: String, default: '../../frontend', docu: 'path to the www root used to server static files'
    value name: 'port', type: Integer, default: 8000, docu: 'the port on which the webserver listens for the interface'
    value name: 'interface', type: String, default: "127.0.0.1", docu: 'the interface on which the webserver listens for the interface'
  end

  value name: 'redis' do
    value name: 'sock_path', type: String, default: 'sockets', docu: 'path to the folder with the unix socket for redis'
    value name: 'log_path', type: String, default: 'log', docu: 'path to the folder with the redis log files'
    value name: 'config_path', type: String, default: 'config', docu: 'path to the folder with the redis config files'
  end
end

