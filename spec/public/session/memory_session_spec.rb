require File.join(File.dirname(__FILE__), "spec_helper")
startup_merb(:session_store => "memory")
require File.join(File.dirname(__FILE__), "controllers", "sessions")

describe Merb::MemorySession, "container" do

  it "should always generate unique session" do
    # Fix session id generation
    Merb::SessionMixin.stub!(:rand_uuid).and_return(1, 1, 2)

    s1 = Merb::MemorySession.generate
    s1.store.store_session(s1.session_id, {:foo => 'bar'})
    s1.session_id.should eql 1

    s2 = Merb::MemorySession.generate
    s2.session_id.should eql 2
    # Cleanup
    s1.store.delete_session(1)
    s2.store.delete_session(2)
  end

  it "should raise exception if unable to generate unique ID" do
    # Fix session id generation
    Merb::SessionMixin.stub!(:rand_uuid).and_return(1, 1)

    s1 = Merb::MemorySession.generate
    s1.store.store_session(s1.session_id, {:foo => 'bar'})

    lambda { s2 = Merb::MemorySession.generate }.should raise_error

    s1.store.delete_session(1)
  end
end

describe Merb::MemorySession do
  
  before do 
    @session_class = Merb::MemorySession
    @session = @session_class.generate
  end
  
  it_should_behave_like "All session-store backends"
  
  it "should have a session_store_type class attribute" do
    @session.class.session_store_type.should == :memory
  end
  
end

describe Merb::MemorySession, "mixed into Merb::Controller" do

  before(:all) { @session_class = Merb::MemorySession }
  
  it_should_behave_like "All session-stores mixed into Merb::Controller"

end
