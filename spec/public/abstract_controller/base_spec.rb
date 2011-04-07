# Specify controller property behaviour.
#
#TODO: migrate tests to other spec files.

require File.join(File.dirname(__FILE__), "spec_helper")

class BasicTestController < Merb::AbstractController
  before :foo_filter

  self._template_root = 'foobar'

  def foo_filter
    true
  end

  def base_postfact_filter
    true
  end
end

class BasicInheritedController < BasicTestController
  before :bar_filter

  def bar_filter
    true
  end

  def inherited_postfact_filter
    true
  end
end

class AnotherInheritedController < BasicTestController
end

startup_merb

describe Merb::AbstractController do
  it "should allow to set a single template root" do
    BasicTestController._template_roots.should == [['foobar', :_template_location]]
  end

  it "should allow changing the remplate root" do
    BasicTestController._template_root = 'bazqux'
    BasicTestController._template_roots.should == [['bazqux', :_template_location]]
  end

  it "should allow setting multiple template roots" do
    BasicTestController._template_roots = [['a', :_template_location], ['b', :_template_location]]
    BasicTestController._template_roots.should == [['a', :_template_location], ['b', :_template_location]]
  end
end

describe Merb::AbstractController, "under inheritance" do
  it "should inherit filters" do
    BasicTestController._before_filters.size.should == 1
    BasicInheritedController._before_filters.size.should == 2
  end

  it "should inherit template roots" do
    AnotherInheritedController._template_roots.should == [['foobar', :_template_location]]
  end

  it "should not propagate template root changes to child classes" do
    BasicInheritedController._template_root = 'foobar'
    BasicTestController._template_root = 'bazqux'
    BasicInheritedController._template_roots.should == [['foobar', :_template_location]]
  end

  it "should not propagate template root changes to parent classes" do
    BasicTestController._template_root = 'foobar'
    BasicInheritedController._template_root = 'bazqux'
    BasicTestController._template_roots.should == [['foobar', :_template_location]]
  end

  it "setting multiple template roots should not modify child classes" do
    BasicInheritedController._template_root = 'bazqux'
    BasicTestController._template_roots = [['a', :_template_location], ['b', :_template_location]]
    BasicTestController._template_roots.should == [['a', :_template_location], ['b', :_template_location]]
    BasicInheritedController._template_roots.size.should == 1
  end
end
