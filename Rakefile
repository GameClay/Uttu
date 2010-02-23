require 'rubygems'
require 'rake/gempackagetask'

spec = Gem::Specification.new do |s|
  s.name = "github_post_receive_server"
  s.version = "0.0.2"
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ["README", "LICENSE", 'TODO']
  s.summary = "A post commit handler server for GitHub, built on Rack"
  s.description = s.summary
  s.author = "James Tucker"
  s.email = "jftucker@gmail.com"
#  s.homepage = "http://code.ra66i.org/github_post_receive_server"
  
  s.add_dependency "rack"
  
  s.require_path = 'lib'
  #s.autorequire = 'github_post_receive_server'
  
  s.files = %w(LICENSE README Rakefile TODO) + 
            Dir.glob("{bin,lib,specs}/**/*")
            
  s.bindir = 'bin'
  s.executables = %w[
    github_post_receive_server
    github_post_receive_server.ru
  ]
  s.default_executable = 'github_post_receive_server'
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

desc "run all bacon specs"
task :spec do
  sh %{bacon spec/**/*_spec.rb}
end
task :test => :spec

def thin_cmd
  "--rackup bin/github_post_receive_server.ru --port 9001 --pid workflow.pid"
end

desc "start server under thin (rackup)"
task :start do
  sh %{thin #{thin_cmd} start & echo $! > workflow.pid}
end

desc "stop server under thin (rackup)"
task :stop do
  sh %{thin #{thin_cmd} stop}
  sh %{rm tmp/pids/thin.pid}
end

desc "execute a cijoe runner command"
task :cijoe do
  sh %{rake stop}
end

desc "remove pkg files"
task :clean do
  rm_rf 'pkg'
end

desc "run specs"
task :default => :spec