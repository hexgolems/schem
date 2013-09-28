# encoding: utf-8
args = ARGV
args = %w{make test doc show} if args==[]

def shell(*cmd)
  system("zsh","-c",cmd.join(" "))
end

def on_watch(&block)
  block.call()
  puts "watching for changes"
  loop do
    shell("inotifywait --exclude '\..*\.sw[px]*$|4913|~$' -e create -e delete -e modify -r lib/ spec/ > /dev/null 2>/dev/null")
    block.call()
    sleep(0.3)
  end
end

def test
# shell('rspec -r ./spec/spec_helper.rb --color spec/plugin_manager_spec.rb')
 shell('rspec -r ./spec/spec_helper.rb --color spec/**/*.rb')
# shell('rubocop lib/**/*.rb spec/**/*.rb')
end

def doc
  shell('yard --plugin rspec lib/**/* spec/**/*')
end

def show
  shell('firefox coverage/index.html doc/index.html')
end

def run
  pid = fork do
    on_watch do
      puts "[RERUNNING TOOLS]".center(80,"=")
      test
#     shell("ctags spec/**/*.rb lib/**/*.rb > /dev/null")
#     doc
      puts "[DONE]".center(80,"=")
    end
  end
  if pid > 0
    Signal.trap("INT") do
      puts "killing for sure"
      gpid = Process.getpgid(0)
      Process.kill("KILL",-gpid)
    end
    Process.waitpid(pid)
  else
    exit
  end
end

def install(cmd)
    puts "Now running #{cmd}"
  if cmd =~ /\Agem install/
    if $with_root
      system("sudo #{cmd}")
    else
      system(cmd)
    end
  else
    system(cmd)
  end
end

def with_root?
  puts "Would you like to install your gems with root? (Answer no if you use rvm or have another valid reason)"
  loop do
    print "Please answer with: [y/n] "
    answer = STDIN.gets.strip
    if answer == "y"
      $with_root = true
      break
    end
    if answer == "n"
      $with_root = false
      break
    end
  end
end

def setup
  with_root?
  install('gem install --no-rdoc --no-ri rspec')
  install('gem install --no-rdoc --no-ri yard')
  install('gem install --no-rdoc --no-ri yard-rspec')
  install('gem install --no-rdoc --no-ri simplecov')
  install('gem install --no-rdoc --no-ri rubocop')
  install('gem install --no-rdoc --no-ri wrong')
  install('sudo apt-get -y install inotify-tools')
  project_dependencies
  build_tools
end

def project_dependencies
  install('gem install --no-rdoc --no-ri redis')
  install('gem install --no-rdoc --no-ri pry')
  install('gem install --no-rdoc --no-ri eventmachine')
  install('gem install --no-rdoc --no-ri em-websockets')
  install('gem install --no-rdoc --no-ri em-http-server')
# install('gem install --no-rdoc --no-ri pry-rescue')
  install('gem install --no-rdoc --no-ri pry-debugger')
  install('sudo apt-get -y install redis-server')
  install('sudo apt-get -y install coffeescript')
  install('sudo apt-get -y install gdbserver')
  install('sudo apt-get -y install gdb')
  install('sudo apt-get -y install mercurial')
  install('sudo apt-get -y install git')
  install('cd ..; mkdir dependencies')
  install('cd ../dependencies; git clone https://github.com/meh/ruby-thread.git thread')
  install('cd ../dependencies; git clone https://github.com/ranmrdrakono/gdb-mi-parser')
  install('cd ../dependencies; hg clone https://code.google.com/p/metasm/')
end

def build_tools
  shell("gcc","run/debugee.c","-o","run/debugee")
  shell("gcc","run/debugee.c","-g","-o","run/debugee_with_debug_info")
  shell("gcc","run/gdbsspawner.c","-o","run/gdbsspawner")
end


build_tools if args.include? 'build'
setup if args.include? 'setup'
test if args.include? 'test'
doc  if args.include? 'doc'
show if args.include? 'show'
run  if args.include? 'run'

