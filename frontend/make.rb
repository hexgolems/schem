# encoding: utf-8
args = ARGV
args = %w{make test doc show} if args==[]

def setup
  project_dependies
end

def project_dependies
  system('sudo apt-get install coffeescript')
end

def run
  system('coffee -w -c -b sockets.cs struct_widget/struct.cs table_widget/table.cs cmd_widget/cmd.cs')
end

run  if args.include? 'run'
