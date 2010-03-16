require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "spec_helper"))

describe Merb::Config do

  it "should set Dispatcher.use_mutex to true by default" do
    lambda {
      startup_merb
      Merb::Dispatcher.use_mutex.should be_true
    }
  end

  it "should set Dispatcher.use_mutex to value in config" do
    lambda {
      startup_merb({:use_mutex => false})
      Merb::Dispatcher.use_mutex.should be_false
    }
  end
end
