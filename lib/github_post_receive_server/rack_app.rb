# 
#  rack_app.rb
#  github_post_commit_server
#
#  Example Rack app for http://github.com/guides/post-receive-hooks
#  
#  Created by James Tucker on 2008-05-11.
#  Copyright 2008 James Tucker
# 

require 'rubygems'
require 'rack'
require 'json'
require 'lighthouse-api'

module GithubPostReceiveServer
  class RackApp
    GO_AWAY_COMMENT = "These are not the droids you are looking for."
    THANK_YOU_COMMENT = "You can go about your business. Move along."

    # This is what you get if you make a request that isn't a POST with a 
    # payload parameter.
    def rude_comment
      @res.write GO_AWAY_COMMENT
    end

    # Does what it says on the tin. By default, not much, it just prints the
    # received payload.
    def handle_request
      payload = @req.POST["payload"]
      
      return rude_comment if payload.nil?
      
      payload = JSON.parse(payload)
      
      # Authenticate with the Lighthouse project
      begin
        # TODO: Put parameters in to ENV or something
        Lighthouse.account = 'gameclay'
        Lighthouse.token = '69b8ab518cdf61624b41efe429d796e08e0a288d'
      rescue
        return "Error authenticating Lighthouse"
      end
      
      # Iterate the commits and check for workflow events
      # TODO: This is not the most expandable thing in the world
      payload['commits'].each do |commit|
        
        # Look for bug fixes
        if commit['message'] =~ /Merge branch '.*\/bug-(\d*)'/
          begin
            # TODO: Put project ID, "resolve state", and message into ENV or something
            ticket = Lighthouse::Ticket.find($1, :params => { :project_id => 47141 })
            ticket.state = 'resolved'
            ticket.body = "Fixed by #{commit['author']['name']}.\n#{commit['url']}"
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