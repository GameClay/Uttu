$TESTING=true
$:.push File.join(File.dirname(__FILE__), '..', 'lib')
require 'rubygems'
require 'mocha'
require 'uttu'

Spec::Runner.configure do |config|
   config.mock_with :mocha
end
