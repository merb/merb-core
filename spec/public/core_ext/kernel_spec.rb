require File.join(File.dirname(__FILE__), "spec_helper")
startup_merb

$:.push File.join(File.dirname(__FILE__), "fixtures")

describe Kernel, "#use_orm" do
  
  before do
    Merb.orm = :none # reset orm
  end
  
  it "should set Merb.orm" do
    Kernel.use_orm(:activerecord)
    Merb.orm.should == :activerecord
  end
end

describe Kernel, "#use_template_engine" do
  
  before do
    Merb.template_engine = :erb # reset template engine
  end
  
  it "should set Merb.template_engine" do
    Kernel.use_template_engine(:haml)
    Merb.template_engine.should == :haml
  end
end

describe Kernel, "#use_test" do
  
  before do
    Merb.test_framework = :rspec # reset test framework
  end
  
  it "should set Merb.test_framework" do
    Kernel.use_test(:test_unit)
    Merb.test_framework.should == :test_unit
  end
end
