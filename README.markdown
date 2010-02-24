# GameClay Workflow GitHub Post Receive Server
This is the Workflow server that wires GameClay GitHub projects in to Lighthouse
for specific git actions.

## Configuration
Running the server will create a template `config.yaml` for you to fill in with the 
Lighthouse account and token.

When the server gets a Post-Receive hit from GitHub, it will use the repository name 
and attempt to find a corresponding Lighthouse project. If it cannot find the GitHub
repository name in the `config.yaml` file it will insert it for you. Simply fill in
the Lighthouse project ID.

### config.yaml
Here is a sample `config.yaml`
    --- 
    LighthouseIntegrationTest: 
      lighthouse_id: 123456
    AnotherGitHubRepository: 
      lighthouse_id: 987654
    lighthouse: 
      token: 71c6c325c4c3d631d09332e64a7acb22aabc65d3
      account: myhappyaccount

### CI Joe
If you use [CI Joe](http://github.com/defunkt/cijoe) with this repository, it can create an auto-updating server.

First assign the CI Joe runner command
    $ git config --add cijoe.runner "rake -s install"

Next create a build-worked hook in .git/hooks/build-worked:
    #!/bin/sh
    rake -s stop
    rake -s start
This will restart the Workflow Post Receieve Hook

## Testing
This server is tested using a public GitHub repository which contains instances of all of workflow events that this server should detect. The repository gets 'repushed' to provide a way to deterministically test the Workflow server's interaction with Lighthouse. More information can be found in the [Lighthouse Integration Test Repository](http://github.com/ZeroStride/LighthouseIntegrationTest). The Lighthouse test project is also [available here](http://gameclay.lighthouseapp.com/projects/47141-workflow-test).

## Workflow Tasks
The Workflow server looks for information in git commit messages.

### Bug Fix Branches
When the post-receive hook sees a message in the format: `Merged branch 'initials/bug-#'` It should mark the corresponding bug as 'fixed'.

## Credits
This code is based off the template rack server at: [raggi/github_post_receive_server](http://github.com/raggi/github_post_receive_server/)