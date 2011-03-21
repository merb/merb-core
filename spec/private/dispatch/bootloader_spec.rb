require File.dirname(__FILE__) + '/spec_helper'

describe Merb::BootLoader::RackUpApplication do

  it "should default to rack config (rack.rb)", :rack => true, :core => true do
    options = {:merb_root => File.dirname(__FILE__) / 'fixture'}
    Merb::Config.setup(options)
    Merb::BootLoader::default_framework
    Merb::BootLoader::RackUpApplication.run

    Merb::Config[:app].should be_kind_of(Merb::Rack::Static)
  end

  it "should use rackup config that we specified", :rack => true, :core => true do
    options = {:rackup => File.dirname(__FILE__) / 'fixture' / 'config' / 'black_hole.rb'}
    Merb::Config.setup(options)
    Merb::BootLoader::RackUpApplication.run
    app = Merb::Config[:app]

    # 1.9 returns "#<Class:0xa716858>::Rack::Adapter::BlackHole"
    app.class.name.should include("Rack::Adapter::BlackHole")

    env = Rack::MockRequest.env_for("/black_hole")
    status, header, body = app.call(env)
    status.should == 200
    header.should == { "Content-Type" => "text/plain" }
    body.should == ""
  end
  
end
