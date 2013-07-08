# encoding: utf-8
args = ARGV
args = %w{make test doc show} if args==[]

def shell(cmd)
  system("zsh","-c",cmd)
end

def on_watch(&block)
  puts "watching for changes"
  loop do
    shell("inotifywait --exclude '\..*\.sw[px]*$|4913|~$' -e create -e delete -e modify -r lib/ spec/ > /dev/null 2>/dev/null")
    block.call()
    sleep(0.3)
  end
end

def test
  shell('rspec -r ./spec/spec_helper.rb --color')
  shell('rubocop lib/**/*.rb spec/**/*.rb')
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
      shell("ctags spec/**/*.rb lib/**/*.rb > /dev/null")
      doc
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

def setup
  system('gem install rspec')
  system('gem install yard')
  system('gem install yard-rspec')
  system('gem install simplecov')
  system('gem install rubocop')
  system('gem install wrong')
  system('sudo apt-get install inotify-tools')
  project_dependencies
end

def project_dependencies
  system('gem install whittle')
  system('gem install celluloid')
  system('gem install redis')
  system('gem install reel')
  system('gem install celluloid-redis')
  system('gem install pry')
  system('gem install pry-debugger')
  system('sudo apt-get install redis-server')
  system('sudo apt-get install coffeescript')
end


test if args.include? 'test'
doc  if args.include? 'doc'
show if args.include? 'show'
run  if args.include? 'run'
setup if args.include? 'setup'

