# Uttu
## GameClay Workflow GitHub Post Receive Server
This is the workflow server that wires GameClay GitHub projects in to Lighthouse for specific git actions.

### Managed Tickets
We can all agree that bug trackers are very useful, and that proper use of version control workflow is very useful. Previously, this included a lot of duplicated effort. When proper use of tools delays the development process on a repetitive basis, any benefit from those tools is harder to see. In order to allow a lead programmer to truly be both a lead, and a programmer Uttu introduces the concept of _managed tickets_ to the project workflow. A managed ticket is kept automatically updated with information Uttu retrieves from GitHub, removing the need to duplicate work in both version control, and bug tracker.

For example: When someone adds a 'TODO' to your code, Uttu will find it and create a ticket for that task, including commit information. If that comment is later deleted, Uttu will resolve the ticket, and include applicable information.

## Configuration
Running the server will create a template `config.yaml` for you to fill in with the Lighthouse subdomain and API token. For more information on Lighthouse API tokens, please see: [How do I get an API token?](https://lighthouse.tenderapp.com/faqs/api/how-do-i-get-an-api-token)

When the server gets a Post-Receive hit from GitHub, it will use the repository name and attempt to find a corresponding Lighthouse project. If it cannot find the GitHub repository name in the `config.yaml` file it will insert it for you. Simply fill in the Lighthouse project ID. 

All edits to config.yaml will apply the next request the server receives.

### Lighthouse Configuration
    lighthouse: 
      token: <lighthouse token>
      account: <lighthouse subdomain>

### Project Configuration
    GitHubRepositoryName:
      lighthouse_id: <corrisponding Lighthouse project id>
      merge_state: <state to mark tickets when Uttu detects a bug-fix merge>

### config.yaml
Here is a sample `config.yaml` (no that is not a valid API token)
    --- 
    LighthouseIntegrationTest: 
      lighthouse_id: 123456
      merge_state: resolved
    AnotherGitHubRepository: 
      lighthouse_id: 987654
      merge_state: fixed
    lighthouse: 
      token: 71c6c325c4c3d631d09332e64a7acb22aabc65d3
      account: mysubdomain

### CI Joe
If you use [CI Joe](http://github.com/defunkt/cijoe) with a fork of this repository, and set it up as a [Post-Receive hook](http://help.github.com/post-receive-hooks/), you can run a self-updating server.

First assign the CI Joe runner command
    $ git config --add cijoe.runner "rake -s install"
This will install Uttu, making the new code that you just pushed to GitHub available at the user, or administrator level (we run Uttu in user mode).

Next create a build-worked hook in .git/hooks/build-worked:
    #!/bin/sh
    rake -s stop
    rake -s start
This will restart Uttu if the rake install task succeeded; your Uttu server now reflects the changes you just pushed.

## Testing
Uttu is tested using a GitHub repository which contains instances of all of workflow events that this server should detect. The repository gets 'repushed' to provide a way to deterministically test Uttu's interaction with Lighthouse. To do this easily, use a simple script. This is the meat of the script:
    git reset --hard _some\_commit_ # Return the repository to a previous state
    git push --force                # Push with --force to return the origin index to the previous state
    git reset --hard HEAD@{1}       # Restore the "last state" of our repository from the reflog
    git push                        # Push all commits to origin

More information can be found in our [Lighthouse Integration Test Repository](http://github.com/ZeroStride/LighthouseIntegrationTest). The Lighthouse test project is also [available here](http://gameclay.lighthouseapp.com/projects/47141/home).

## Workflow Tasks
Uttu looks for information in git commit messages. It then performs Lighthouse API tasks .

### Bug Fix Branches
When Uttu sees a commit to the master branch with the message in the format: `Merged branch 'initials/bug-#'` It will mark the corresponding bug with the state specified in the project's `merge_state`; this defaults to `resolved`.

For example, a branch named `pw/bug-3`

![GitHub graph of a branch called pw/bug-3](http://farm3.static.flickr.com/2722/4392858949_043b9972b6_o.png)

Will cause Uttu to modify the associated ticket.

![Uttu integrating a bug-fix branch](http://farm5.static.flickr.com/4051/4392829731_c9b7f6e14f_o.png)

### TODO's
Uttu will attempt to keep track of the TODO's you add to your code.
![A File Adding a TODO](http://farm3.static.flickr.com/2689/4397061993_cda5b972ed_o.png)

When Uttu gets a commit that has a diff chunk which adds a line with the text "TODO" (and many variations), it will automatically create a task in Lighthouse that links back to the commit, and that file/line so that TODO tasks can be collected on the Lighthouse tracker. Uttu will also look for diff chunks where a TODO gets deleted, and will automatically resolve the associated ticket. 

![Resulting TODO added, and later resolved, by Uttu](http://farm5.static.flickr.com/4043/4397828336_40bf22c315_o.png)

### Feature Branches
Uttu looks for the addition of feature branches to the repository. When it sees the addition of a feature-branch, it creates a managed Lighthouse ticket

## Credits
This code is based off the template located at: [raggi/github_post_receive_server](http://github.com/raggi/github_post_receive_server/)

Uttu is Copyright (c) GameClay LLC