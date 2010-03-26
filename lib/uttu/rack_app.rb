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
require 'twitter'

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
        'github_token' => "github_token_for_github_user",
        'twitter_name' => "Account_to_curse_at",
        'twitter_password' => "Figure_it_out"
      }
    end

    def load_config(payload)
       # Load YAML
       if not File.exists?('config.yaml')
         File.open('config.yaml', 'w') do |out|
           YAML.dump(default_config, out)
         end

         our_error("No 'config.yaml' found. An empty config has been created, please fill it in.")
         return nil
       end

       yamlconfig = YAML.load_file('config.yaml')

       # Find out what repository this is coming from
       repository = payload['repository']
       repoconfig = yamlconfig[repository['name']]

       if repoconfig.nil?
         yamlconfig[repository['name']] = default_repo_config

         File.open('config.yaml', 'w') do |out|
           YAML.dump(yamlconfig, out)
         end

         our_error("No configuration for #{repository['name']}, an entry has been added to config.yaml, please fill it in.")
         return nil
       end
       return yamlconfig
    end

    # Does what it says on the tin. By default, not much, it just prints the
    # received payload.
    def handle_request
      payload = @req.POST["payload"]
      
      return rude_comment if payload.nil?
      
      payload = JSON.parse(payload)
      
      yamlconfig = load_config payload
      return unless yamlconfig
      repository = payload['repository']
      repoconfig = yamlconfig[repository['name']]
      
      # Authentication credentials for Lighthouse
      Lighthouse.account = yamlconfig['lighthouse']['account']
      Lighthouse.token = yamlconfig['lighthouse']['token']
      
      # Find out what ref this commit is using
      branch = "master"
      if payload['ref'] =~ /refs\/heads\/(.*)/  
        branch = $1
      end
      
      # Look for new branches      
      begin
        if Integer(payload['before']) == 0          
          # A new branch (or new repo) has been created, but 
          # if we somehow get here with master, ignore it.
          if branch != "master"
            # Add a ticket to merge this branch 
            ticket = Lighthouse::Ticket.new(:project_id => repoconfig['lighthouse_id'])
            ticket.title = "Review branch: #{$1}"
            ticket.tags << 'branch'
            # TODO: Would be cool to assign a person responsible for merging by default
            ticket.body = "Review branch [#{$1}](http://github.com/#{repository['owner']['name']}/#{repository['name']}/compare/#{$1})"
            puts "Creating merge request ticket for '#{$1}'" if ticket.save
          end                    
        end
      rescue
      end
      
      puts "Parsing commits from repository: #{repository['name']}"
      
      # Iterate the commits and check for workflow events
      # TODO: This is not the most expandable thing in the world
      payload['commits'].each do |commit|
        
        # Look for some specific events on the master branch
        if branch == "master"
        
          # Look for bug fixes
          if commit['message'] =~ /Merge branch '.*\/(bug|task)-(\d*).*'/
            begin
              ticket = Lighthouse::Ticket.find($2, :params => { :project_id => repoconfig['lighthouse_id'] })
              ticket.state = repoconfig['merge_state']
              ticket.body = "Fixed by #{commit['author']['name']} in [#{commit['id']}]\n#{commit['url']}"
              puts "Marking ticket #{$2} fixed (#{commit['message']})" if ticket.save
            rescue
              puts "Error updating ticket #{$2} (#{commit['message']})"
            end
          end
        
          # Look for feature branch integrations
          if commit['message'] =~ /Merge branch '(.*)'/
            tickets = Lighthouse::Ticket.find(:all, :params => { :project_id => repoconfig['lighthouse_id'], 
              :q => "tagged:branch not-state:resolved" })
          
              begin
                tickets.each do |ticket|
                  if ticket.title == "Review branch: #{$1}"
                    ticket.state = repoconfig['merge_state']
                    ticket.body = "Merged by #{commit['author']['name']} in [#{commit['id']}]\n#{commit['url']}"
                    puts "Resolving Lighthouse ticket '#{ticket.title}'" if ticket.save
                  end
                end
              rescue
                puts "Error resolving Lighthouse ticket: #{$!}"
              end
          end
        end # end master branch stuff (TODO: This one-file, no-objects approach has got to be fixed.)
        
        # TODO: Look for commits made to branches, and update any associated tickets
        
        # Look for TODO's in commit diffs
        if branch == "master"
          begin
            authenticated_with(:login => repoconfig['github_user'], :token => repoconfig['github_token']) do 
              gh_commit = Octopi::Commit.find(:user => "#{repository['owner']['name']}", :repo => "#{repository['name']}", :sha => "#{commit['id']}")

              #puts "Commit: #{gh_commit.id} - #{gh_commit.message} - by #{gh_commit.author['name']}"
            
              # This is uber-lame
              gh_url = "https://github.com/#{repository['owner']['name']}/#{repository['name']}/blob/#{commit['id']}/"

              # Check array of added files for new TODO's
              gh_commit.added.each do |addition|
                todo_parse_diff(addition, gh_url, repoconfig, commit)
                curse_parse_diff(addition, gh_url, repoconfig, commit)
              end

              # Check array of removed files for removed TODO's
              gh_commit.removed.each do |removal|
                todo_parse_diff(removal, gh_url, repoconfig, commit)
              end

              # Check array of modified files for new TODO's and removed TODO's
              gh_commit.modified.each do |modifyee|
                todo_parse_diff(modifyee, gh_url, repoconfig, commit)
                curse_parse_diff(modifyee, gh_url, repoconfig, commit)
              end
            end
          rescue Octopi::InvalidLogin
            puts "Invalid login"
          rescue
            puts "#{$!}"
          end
        end # end TODO parsing
        
      end
      
      @res.write THANK_YOU_COMMENT
    end
    
    def curse_parse_diff(diff, gh_url, repoconfig, commit)
       filename = diff['filename']
       p "Checking for curse in #{filename}"

       # Parse each diff chunk
       begin
         diff['diff'].scan(/@@ \-(\d+),(\d+) \+(\d+),(\d+) @@(.*\s)/) do |diff|
           # puts "#{filename} -#{$1}, #{$2} +#{$3}, #{$4}"

           $'.each_line do |line|

             # Line added
             if line =~ /^\+(.*)/

               mainline = $1
               mainline.strip!
               p "Checking #{mainline}"
               httpauth = Twitter::HTTPAuth.new(repoconfig['twitter_name'], repoconfig['twitter_password'])
               client = Twitter::Base.new httpauth
               if mainline =~ /.*fuck.*/i
                  p "Curse!"
                  client.update(mainline)
               elsif mainline =~ /.*shit.*/i
                  p "Curse!"
                  client.update(mainline)
               elsif mainline =~ /.*cock.*/i
                  p "Curse!"
                  client.udpate(mainline)
               elsif mainline =~ /.*bitch.*/i
                  p "Curse!"
                  client.udpate(mainline)
               elsif mainline =~ /.*cunt.*/i
                  p "Curse!"
                  client.udpate(mainline)
               elsif mainline =~ /.*bastard.*/i
                  p "Curse!"
                  client.udpate(mainline)
               elsif mainline =~ /.*dick.*/i
                  p "Curse!"
                  client.udpate(mainline)
               elsif mainline =~ /.*whore.*/i
                  p "Curse!"
                  client.udpate(mainline)
               elsif mainline =~ /.*goddman.*/i
                  p "Curse!"
                  client.udpate(mainline)
               elsif mainline =~ /.*asshole.*/i
                  p "Curse!"
                  client.udpate(mainline)
               end
            end
         end
      end
   end
   end
    
    # Temp function to parse diffs for todo
    def todo_parse_diff(diff, gh_url, repoconfig, commit)
      
      filename = diff['filename']
      
      # Parse each diff chunk
      begin
        diff['diff'].scan(/@@ \-(\d+),(\d+) \+(\d+),(\d+) @@(.*\s)/) do |diff|
          # puts "#{filename} -#{$1}, #{$2} +#{$3}, #{$4}"
        
          addLine = Integer($3)
          delLine = Integer($1)
          $'.each_line do |line|
          
            # Line added
            if line =~ /^\+(.*)/
            
              # Look for a TODO added
              if $1 =~ /[Tt][Oo][Dd][Oo][:\-\s]*(.*)/
                begin
                  # Add a ticket
                  ticket = Lighthouse::Ticket.new(:project_id => repoconfig['lighthouse_id'])
                  ticket.title = $1
                  ticket.tags << 'todo'
                  ticket.body = "Created by #{commit['author']['name']} in file: [#{filename}](#{gh_url}#{filename}#L#{addLine})\n[#{commit['id']}]"
                  puts "Creating TODO '#{$1}'" if ticket.save
                rescue
                  puts "Error creating new Lighthouse ticket: #{$!}"
                end
              end
            
              addLine = addLine + 1
            
            # Line removed
            elsif line =~ /^\-(.*)/
            
              # Look for a TODO removed
              if $1 =~ /[Tt][Oo][Dd][Oo][:\-\s]*(.*)/
                begin
                  tickets = Lighthouse::Ticket.find(:all, :params => { :project_id => repoconfig['lighthouse_id'], 
                    :q => "tagged:todo not-state:resolved keyword:\"#{filename}\"" })
                
                  begin
                    tickets.each do |ticket|
                      if ticket.title == $1
                        ticket.state = repoconfig['merge_state']
                        ticket.body = "Removed by #{commit['author']['name']} in file: [#{filename}](#{gh_url}#{filename}#L#{delLine})\n[#{commit['id']}]"
                        puts "Resolving Lighthouse ticket '#{ticket.title}'" if ticket.save
                      end
                    end
                  rescue
                    puts "Error resolving Lighthouse ticket: #{$!}"
                  end
                rescue
                  puts "Error searching Lighthouse tickets: #{$!}"
                end
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
      rescue
      end
      
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