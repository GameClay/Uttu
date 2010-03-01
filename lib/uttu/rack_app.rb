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
require 'octopi'

include Octopi
  
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
    
    def default_repo_config
      { 
        'lighthouse_id' => "your_lighthouse_project_id", 
        'merge_state' => "resolved",
        'github_user' => "github_user_with_access_to_this_repo",
        'github_token' => "github_token_for_github_user"
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
        yamlconfig[repository['name']] = default_repo_config
        
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
        
        # Look for TODO's in commit diffs
        begin
          authenticated_with(:login => repoconfig['github_user'], :token => repoconfig['github_token']) do 
            gh_commit = Octopi::Commit.find(:user => "#{repository['owner']['name']}", :repo => "#{repository['name']}", :sha => "#{commit['id']}")

            #puts "Commit: #{gh_commit.id} - #{gh_commit.message} - by #{gh_commit.author['name']}"

            # Check array of added files for new TODO's
            gh_commit.added.each do |addition|
              todo_parse_diff(addition)
            end

            # Check array of removed files for removed TODO's
            # TODO...
            # gh_commit.removed.each do |removal|
            #   todo_parse_diff(removal)
            # end

            # Check array of modified files for new TODO's
            # and removed TODO's
            gh_commit.modified.each do |modifyee|
              todo_parse_diff(modifyee)
            end
          end
        rescue Octopi::InvalidLogin
          puts "Invalid login"
        rescue
          puts "#{$!}"
        end
      end
      
      @res.write THANK_YOU_COMMENT
    end
    
    # Temp function to parse diffs for todo
    def todo_parse_diff(octopi_in)
      
      # Parse what we get from Octopi
      if "#{octopi_in}" =~ /^filename([A-Za-z0-9_\-\.]*)diff((.|\s)*)/
        filename = $1
        
        # Parse each diff chunk
        $2.scan(/@@ \-(\d+),(\d+) \+(\d+),(\d+) @@()/) do |diff|
          # puts "#{filename} -#{$1}, #{$2} +#{$3}, #{$4}"
          
          addLine = Integer($3)
          delLine = Integer($1)
          $'.each_line do |line|
            
            # Line added
            if line =~ /^\+(.*)/
              
              # Look for a TODO added
              if $1 =~ /[Tt][Oo][Dd][Oo][:\-\s]*(.*)/
                puts "+[#{addLine}]Todo: '#{$1}'..."
              end
              
              addLine = addLine + 1
              
            # Line removed
            elsif line =~ /^\-(.*)/
              
              # Look for a TODO removed
              if $1 =~ /[Tt][Oo][Dd][Oo][:\-\s]*(.*)/
                puts "-[#{delLine}]Todo: '#{$1}'..."
              end
              
              delLine = delLine + 1
              
            # Line starts with @@, break this loop and hit the
            # next regexp match
            elsif line =~ /^@@/
            
              break # Go to the next match
              
            # Line starts with +, - or whitespace, avoiding
            # something like '\ No newline at end of file'
            elsif line =~ /^[\+\-\s]/
              addLine = addLine + 1
              delLine = delLine + 1
            end
            
          end # end each_line iteration
          
        end # end diff chunk matching
        
      end # end parse Octopi input
      
    end # end method

    # Call is the entry point for all rack apps.
    def call(env)
      @req = Rack::Request.new(env)
      @res = Rack::Response.new
      handle_request
      @res.finish
    end
  end
end