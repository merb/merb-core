require File.join(File.dirname(__FILE__), "spec_helper")

class MyKontroller < Merb::Controller
end

describe "attempting to override a method in Merb::Controller" do
  it "raises an error" do
    expect do
      MyKontroller.class_eval do
        def status
        end
      end
    end.to raise_error(Merb::ReservedError)
  end

  it "doesn't raise an error if override! is called" do
    expect do
      MyKontroller.class_eval do
        override! :status
        def status
        end
      end
    end.to_not raise_error
  end
end
