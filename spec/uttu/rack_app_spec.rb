require File.dirname(__FILE__) + '/../spec_helper'

describe "Rack Post-Receive Server :-P" do 
  before :each do
    @server = Uttu::RackApp.new
  end
  
  it "should reply with a rude message on GET" do 
    req = Rack::MockRequest.new(@server)
    res = req.get("/")
    res.should be_ok
  end
  it "should reply with a rude message on GET" do 
    req = Rack::MockRequest.new(@server)
    res = req.post("/", {})
    res.should be_ok
  end
  
  GITHUB_JSON = <<-GITHUB_JSON
  {
    "before": "5aef35982fb2d34e9d9d4502f6ede1072793222d",
    "repository": {
      "url": "http://github.com/defunkt/github",
      "name": "github",
      "description": "You're lookin' at it.",
      "watchers": 5,
      "forks": 2,
      "private": 1,
      "owner": {
        "email": "chris@ozmm.org",
        "name": "defunkt"
      }
    },
    "commits": [
      {
        "id": "41a212ee83ca127e3c8cf465891ab7216a705f59",
        "url": "http://github.com/defunkt/github/commit/41a212ee83ca127e3c8cf465891ab7216a705f59",
        "author": {
          "email": "chris@ozmm.org",
          "name": "Chris Wanstrath"
        },
        "message": "okay i give in",
        "timestamp": "2008-02-15T14:57:17-08:00",
        "added": ["filepath.rb"]
      },
      {
        "id": "de8251ff97ee194a289832576287d6f8ad74e3d0",
        "url": "http://github.com/defunkt/github/commit/de8251ff97ee194a289832576287d6f8ad74e3d0",
        "author": {
          "email": "chris@ozmm.org",
          "name": "Chris Wanstrath"
        },
        "message": "update pricing a tad",
        "timestamp": "2008-02-15T14:36:34-08:00"
      }
    ],
    "after": "de8251ff97ee194a289832576287d6f8ad74e3d0",
    "ref": "refs/heads/master"
  }
  GITHUB_JSON
  
  it "should reply with a nice message on POST with a payload" do 
     object = mock('Octopi::Commit')
     object.stubs(:added).returns([])
     object.stubs(:removed).returns([])
     object.stubs(:modified).returns([])
     Octopi::Commit.stubs(:find).returns(object)
     Octopi::User.stubs(:find).returns(true)
     
    req = Rack::MockRequest.new(@server)
    res = req.post("/", :input => "payload=#{GITHUB_JSON}")
    res.should be_ok
  end
end

describe "New branch behavior" do
   before :each do
     @server = Uttu::RackApp.new
   end
   
   it "should create a review ticket when a new branch is posted" do
      NEW_BRANCH_JSON = <<-NEW_BRANCH_JSON
      {
         "before": "0000000000000000000000000000000000000000",
         "repository": {
         "url": "http://github.com/defunkt/github",
         "name": "github",
         "description": "You're lookin' at it.",
         "watchers": 5,
         "forks": 2,
         "private": 1,
         "owner": {
            "email": "chris@ozmm.org",
            "name": "defunkt"
         }
      },
      "commits": [
      {
         "id": "41a212ee83ca127e3c8cf465891ab7216a705f59",
         "url": "http://github.com/defunkt/github/commit/41a212ee83ca127e3c8cf465891ab7216a705f59",
         "author": {
            "email": "chris@ozmm.org",
            "name": "Chris Wanstrath"
         },
         "message": "okay i give in",
         "timestamp": "2008-02-15T14:57:17-08:00",
         "added": ["filepath.rb"]
      }
      ],
         "after": "41a212ee83ca127e3c8cf465891ab7216a705f59",
         "ref": "refs/heads/new-branch"
      }
      NEW_BRANCH_JSON
      object = mock('Octopi::Commit')
      object.stubs(:added).returns([])
      object.stubs(:removed).returns([])
      object.stubs(:modified).returns([])
      Octopi::Commit.stubs(:find).returns(object)
      Octopi::User.stubs(:find).returns(true)
      
      ticket = Lighthouse::Ticket.new(:project_id => 12345)
      ticket.expects(:save).returns(true)
      Lighthouse::Ticket.expects(:new).returns(ticket)
      
      req = Rack::MockRequest.new(@server)
      res = req.post("/", :input => "payload=#{NEW_BRANCH_JSON}")
      res.should be_ok
      ticket.title.should include "Review branch: new-branch"
      ticket.tags.should include "branch"
      ticket.body.should include "/compare/new-branch"
   end
   
   it "should not create a review ticket for master" do
      NEW_BRANCH_JSON = <<-NEW_BRANCH_JSON
      {
         "before": "0000000000000000000000000000000000000000",
         "repository": {
         "url": "http://github.com/defunkt/github",
         "name": "github",
         "description": "You're lookin' at it.",
         "watchers": 5,
         "forks": 2,
         "private": 1,
         "owner": {
            "email": "chris@ozmm.org",
            "name": "defunkt"
         }
      },
      "commits": [
      {
         "id": "41a212ee83ca127e3c8cf465891ab7216a705f59",
         "url": "http://github.com/defunkt/github/commit/41a212ee83ca127e3c8cf465891ab7216a705f59",
         "author": {
            "email": "chris@ozmm.org",
            "name": "Chris Wanstrath"
         },
         "message": "okay i give in",
         "timestamp": "2008-02-15T14:57:17-08:00",
         "added": ["filepath.rb"]
      }
      ],
         "after": "41a212ee83ca127e3c8cf465891ab7216a705f59",
         "ref": "refs/heads/master"
      }
      NEW_BRANCH_JSON
      object = mock('Octopi::Commit')
      object.stubs(:added).returns([])
      object.stubs(:removed).returns([])
      object.stubs(:modified).returns([])
      Octopi::Commit.stubs(:find).returns(object)
      Octopi::User.stubs(:find).returns(true)
      
      Lighthouse::Ticket.expects(:new).never()
      
      req = Rack::MockRequest.new(@server)
      res = req.post("/", :input => "payload=#{NEW_BRANCH_JSON}")
      res.should be_ok
   end
end

describe "Merge task branch" do
   before :each do
     @server = Uttu::RackApp.new
   end
   
   it "should mark the bug ticket as resolved" do
      GITHUB_JSON = <<-GITHUB_JSON
      {
        "before": "5aef35982fb2d34e9d9d4502f6ede1072793222d",
        "repository": {
          "url": "http://github.com/defunkt/github",
          "name": "github",
          "description": "You're lookin' at it.",
          "watchers": 5,
          "forks": 2,
          "private": 1,
          "owner": {
            "email": "chris@ozmm.org",
            "name": "defunkt"
          }
        },
        "commits": [
          {
            "id": "41a212ee83ca127e3c8cf465891ab7216a705f59",
            "url": "http://github.com/defunkt/github/commit/41a212ee83ca127e3c8cf465891ab7216a705f59",
            "author": {
              "email": "chris@ozmm.org",
              "name": "Chris Wanstrath"
            },
            "message": "okay i give in",
            "timestamp": "2008-02-15T14:57:17-08:00",
            "added": ["filepath.rb"]
          },
          {
            "id": "de8251ff97ee194a289832576287d6f8ad74e3d0",
            "url": "http://github.com/defunkt/github/commit/de8251ff97ee194a289832576287d6f8ad74e3d0",
            "author": {
              "email": "chris@ozmm.org",
              "name": "Chris Wanstrath"
            },
            "message": "Merge branch 'cw/bug-11-remove-ggconnect'",
            "timestamp": "2008-02-15T14:36:34-08:00"
          }
        ],
        "after": "de8251ff97ee194a289832576287d6f8ad74e3d0",
        "ref": "refs/heads/master"
      }
      GITHUB_JSON
      object = mock('Octopi::Commit')
      object.stubs(:added).returns([])
      object.stubs(:removed).returns([])
      object.stubs(:modified).returns([])
      Octopi::Commit.stubs(:find).returns(object)
      Octopi::User.stubs(:find).returns(true)
      
      ticket = Lighthouse::Ticket.new(:project_id => 12345)
      ticket.expects(:save).returns(true)
      Lighthouse::Ticket.expects(:find).with("11", :params => { :project_id => 12345 }).returns(ticket)
      Lighthouse::Ticket.expects(:find).with(:all, {:params => {:q => 'tagged:branch not-state:resolved', :project_id => 12345}}).returns([])
      
      req = Rack::MockRequest.new(@server)
      res = req.post("/", :input => "payload=#{GITHUB_JSON}")
      res.should be_ok
      ticket.state.should include "resolved"
      ticket.body.should include "Chris Wanstrath"
      ticket.body.should include "http://github.com/defunkt/github/commit/de8251ff97ee194a289832576287d6f8ad74e3d0"
   end
   
   it "should mark the task ticket as resolved" do
      GITHUB_JSON = <<-GITHUB_JSON
      {
        "before": "5aef35982fb2d34e9d9d4502f6ede1072793222d",
        "repository": {
          "url": "http://github.com/defunkt/github",
          "name": "github",
          "description": "You're lookin' at it.",
          "watchers": 5,
          "forks": 2,
          "private": 1,
          "owner": {
            "email": "chris@ozmm.org",
            "name": "defunkt"
          }
        },
        "commits": [
          {
            "id": "41a212ee83ca127e3c8cf465891ab7216a705f59",
            "url": "http://github.com/defunkt/github/commit/41a212ee83ca127e3c8cf465891ab7216a705f59",
            "author": {
              "email": "chris@ozmm.org",
              "name": "Chris Wanstrath"
            },
            "message": "okay i give in",
            "timestamp": "2008-02-15T14:57:17-08:00",
            "added": ["filepath.rb"]
          },
          {
            "id": "de8251ff97ee194a289832576287d6f8ad74e3d0",
            "url": "http://github.com/defunkt/github/commit/de8251ff97ee194a289832576287d6f8ad74e3d0",
            "author": {
              "email": "chris@ozmm.org",
              "name": "Chris Wanstrath"
            },
            "message": "Merge branch 'cw/task-11-remove-ggconnect'",
            "timestamp": "2008-02-15T14:36:34-08:00"
          }
        ],
        "after": "de8251ff97ee194a289832576287d6f8ad74e3d0",
        "ref": "refs/heads/master"
      }
      GITHUB_JSON
      object = mock('Octopi::Commit')
      object.stubs(:added).returns([])
      object.stubs(:removed).returns([])
      object.stubs(:modified).returns([])
      Octopi::Commit.stubs(:find).returns(object)
      Octopi::User.stubs(:find).returns(true)
      
      ticket = Lighthouse::Ticket.new(:project_id => 12345)
      ticket.expects(:save).returns(true)
      Lighthouse::Ticket.expects(:find).with("11", :params => { :project_id => 12345 }).returns(ticket)
      Lighthouse::Ticket.expects(:find).with(:all, {:params => {:q => 'tagged:branch not-state:resolved', :project_id => 12345}}).returns([])
      
      req = Rack::MockRequest.new(@server)
      res = req.post("/", :input => "payload=#{GITHUB_JSON}")
      res.should be_ok
      ticket.state.should include "resolved"
      ticket.body.should include "Chris Wanstrath"
      ticket.body.should include "http://github.com/defunkt/github/commit/de8251ff97ee194a289832576287d6f8ad74e3d0"
   end
   
   it "should resolve review requests" do
      GITHUB_JSON = <<-GITHUB_JSON
      {
        "before": "5aef35982fb2d34e9d9d4502f6ede1072793222d",
        "repository": {
          "url": "http://github.com/defunkt/github",
          "name": "github",
          "description": "You're lookin' at it.",
          "watchers": 5,
          "forks": 2,
          "private": 1,
          "owner": {
            "email": "chris@ozmm.org",
            "name": "defunkt"
          }
        },
        "commits": [
          {
            "id": "de8251ff97ee194a289832576287d6f8ad74e3d0",
            "url": "http://github.com/defunkt/github/commit/de8251ff97ee194a289832576287d6f8ad74e3d0",
            "author": {
              "email": "chris@ozmm.org",
              "name": "Chris Wanstrath"
            },
            "message": "Merge branch 'cw/awesome-new-feature'",
            "timestamp": "2008-02-15T14:36:34-08:00"
          }
        ],
        "after": "de8251ff97ee194a289832576287d6f8ad74e3d0",
        "ref": "refs/heads/master"
      }
      GITHUB_JSON
      object = mock('Octopi::Commit')
      object.stubs(:added).returns([])
      object.stubs(:removed).returns([])
      object.stubs(:modified).returns([])
      Octopi::Commit.stubs(:find).returns(object)
      Octopi::User.stubs(:find).returns(true)
      
      ticket = Lighthouse::Ticket.new(:project_id => 12345)
      ticket.title = "Review branch: cw/awesome-new-feature"
      ticket.expects(:save).returns(true)
      
      ticket1 = Lighthouse::Ticket.new(:project_id => 12345)
      ticket1.title = "Unrelated thingy"
      ticket.expects(:save).never
      Lighthouse::Ticket.expects(:find).with(:all, {:params => {:q => 'tagged:branch not-state:resolved', :project_id => 12345}}).returns([ticket, ticket1])
      
      req = Rack::MockRequest.new(@server)
      res = req.post("/", :input => "payload=#{GITHUB_JSON}")
      res.should be_ok
      
      ticket.state.should include "resolved"
      ticket.body.should include "Chris Wanstrath"
      ticket.body.should include "http://github.com/defunkt/github/commit/de8251ff97ee194a289832576287d6f8ad74e3d0"
   end
end