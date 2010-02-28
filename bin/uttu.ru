#!/usr/bin/env rackup
begin
  require 'rubygems'
  require 'ruby'
rescue LoadError
  require File.dirname(__FILE__) + '/../lib/uttu'
end

use Rack::CommonLogger
use Rack::Lint
run Uttu::RackApp.new