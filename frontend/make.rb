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
  system('coffee -w -c -b sockets.cs buttons_widget/buttons.cs cmd_widget/cmd.cs dialog_plugin/dialog.cs jquery-ui/development-bundle/docs lane_widget/lane.cs mem_widget/mem.cs sockets.cs struct_widget/struct.cs table_widget/table.cs')
end

run  if args.include? 'run'
