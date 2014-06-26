# encoding: utf-8
args = ARGV
args = %w{build} if args==[]

$files = "sockets.cs buttons_widget/buttons.cs cmd_widget/cmd.cs dialog_plugin/dialog.cs jquery-ui/development-bundle/docs lane_widget/lane.cs mem_widget/mem.cs sockets.cs struct_widget/struct.cs table_widget/table.cs"

def setup
  project_dependies
end

def project_dependies
  system('sudo apt-get install coffeescript')
end

def run
  system("coffee -w -c -b #{$files}")
end

def build
  system("coffee -c -b #{$files}")
end

build if args.include? 'build'
run  if args.include? 'run'
