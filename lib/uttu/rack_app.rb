# 
#  rack_app.rb
#  uttu
#
#  
#  
#  Based on Example Rack app for http://github.com/guides/post-receive-hooks 
#             by James Tucker on 2008-05-11.
#  Copyright 2010 GameClay LLC
#  Portions Copyright 2008 James Tucker
# 

require 'rubygems'
require 'rack'
require 'json'
require 'lighthouse-api'
require 'yaml'

module Uttu
  class RackApp
    GO_AWAY_COMMENT = "These are not the droids you are looking for."
    THANK_YOU_COMMENT = "You can go about your business. Move along."

    # This is what you get if you make a request that isn't a POST with a 
    # payload parameter.
    def rude_comment
      @res.write GO_AWAY_COMMENT
    end
    
    # Our error
    def our_error(error_string)
      puts error_string
      @res.write "We blew it, but we'll fix it soon!"
    end
    
    def default_config
      {
        'lighthouse' => {
          'account' => "your_account_name",
          'token' => "your_rw_token"
        },
      }
    end

    # Does what it says on the tin. By default, not much, it just prints the
    # received payload.
    def handle_request
      payload = @req.POST["payload"]
      
      return rude_comment if payload.nil?
      
      payload = JSON.parse(payload)
      
      # Load YAML
      if not File.exists?('config.yaml')
        File.open('config.yaml', 'w') do |out|
          YAML.dump(default_config, out)
        end
        
        return our_error("No 'config.yaml' found. An empty config has been created, please fill it in.")
      end
      
      yamlconfig = YAML.load_file('config.yaml')
      
      # Authentication credentials for Lighthouse
      Lighthouse.account = yamlconfig['lighthouse']['account']
      Lighthouse.token = yamlconfig['lighthouse']['token']
      
      # Find out what repository this is coming from
      repository = payload['repository']
      repoconfig = yamlconfig[repository['name']]
      
      if repoconfig == nil
        yamlconfig[repository['name']] = { 'lighthouse_id' => "your_lighthouse_project_id", 'merge_state' => "resolved" }
        
        File.open('config.yaml', 'w') do |out|
          YAML.dump(yamlconfig, out)
        end
        
        return our_error("No configuration for #{repository['name']}, an entry has been added to config.yaml, please fill it in.")
      end
      
      puts "Parsing commits from repository: #{repository['name']}"
      
      # Iterate the commits and check for workflow events
      # TODO: This is not the most expandable thing in the world
      payload['commits'].each do |commit|
        
        # Look for bug fixes
        if commit['message'] =~ /Merge branch '.*\/bug-(\d*)'/
          begin
            ticket = Lighthouse::Ticket.find($1, :params => { :project_id => repoconfig['lighthouse_id'] })
            ticket.state = repoconfig['merge_state']
            ticket.body = "Fixed by #{commit['author']['name']} in [#{commit['id']}]\n#{commit['url']}"
            puts "Marking ticket #{$1} fixed (#{commit['message']})" if ticket.save
          rescue
            puts "Error updating ticket #{$1} (#{commit['message']})"
          end
        end
        
      end
      
      @res.write THANK_YOU_COMMENT
    end

    # Call is the entry point for all rack apps.
    def call(env)
      @req = Rack::Request.new(env)
      @res = Rack::Response.new
      handle_request
      @res.finish
    end
  end
end