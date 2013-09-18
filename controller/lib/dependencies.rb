libdir = []
libdir << File.expand_path(File.join(File.dirname(__FILE__),'../../dependencies/thread/lib/'))
libdir << File.expand_path(File.join(File.dirname(__FILE__),'../../dependencies/metasm/'))
libdir << File.expand_path(File.join(File.dirname(__FILE__),'../../dependencies/gdb-mi-parser/'))
libdir.each do |path|
  $LOAD_PATH.unshift path
end
