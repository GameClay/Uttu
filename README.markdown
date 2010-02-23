## GameClay Workflow GitHub Post Receive Server

### CI Joe
If you use CI Joe with this repository, it can create an auto-updating server.

First assign the CI Joe runner command
    $ git config --add cijoe.runner "rake -s install"

Next create a build-worked hook in .git/hooks/build-worked:
    #!/bin/sh
    rake -s stop
    rake -s start
This will restart the Workflow Post Receieve Hook

This server is based off of http://github.com/raggi/github_post_receive_server/