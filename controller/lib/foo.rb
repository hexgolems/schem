require_relative './include.rb'
require_relative './logger/logger.rb'
Schem.init_logger
Pry.rescue_in_pry do
  puts "hi"
end
