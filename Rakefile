require 'rubygems'
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name = "uttu"
  s.version = "0.0.1"
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README.markdown", "LICENSE", 'TODO']
  s.summary = "A Lighthouse-GitHub workflow integration server built on Rack."
  s.description = s.summary
  s.author = "Pat Wilson"
  s.email = "zerostride@gmail.com"
  s.homepage = "http://github.com/GameClay/Uttu"
  
  s.add_dependency "rack"
  s.add_dependency "lighthouse-api"
  s.add_dependency "octopi"
  
  s.require_path = 'lib'
  
  s.files = %w(LICENSE README.markdown Rakefile TODO) + 
            Dir.glob("{bin,lib,specs}/**/*")
            
  s.bindir = 'bin'
  s.executables = %w[
    uttu
    uttu.ru
  ]
  s.default_executable = 'uttu'
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end

desc "install the rubygem"
task :install => [:package] do
  sh %{gem install pkg/#{spec.name}-#{spec.version}}
end

desc "uninstall the rubygem"
task :uninstall => [:package] do
  sh %{gem uninstall #{spec.name}}
end

desc "run all rspec specs"
task :spec do
  sh %{spec spec/**/*_spec.rb}
end
task :test => :spec

def thin_pidfile
  "uttu.pid"
end

def thin_logfile
  "uttu.log"
end

def thin_cmd
  "--rackup bin/uttu.ru --port 9001 --pid #{thin_pidfile} --log #{thin_logfile}"
end

desc "start server under thin (rackup)"
task :start do
  sh %{thin #{thin_cmd} start & echo $! > #{thin_pidfile}}
end

desc "stop server under thin (rackup)"
task :stop do
  if File.exists?(thin_pidfile)
    sh %{thin #{thin_cmd} stop}
    rm_rf thin_pidfile
  end
end

desc "remove pkg files"
task :clean do
  rm_rf 'pkg'
end

desc "run specs"
task :default => :spec
