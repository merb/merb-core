require File.join(File.dirname(__FILE__), "..", "spec_helper")

describe "When recognizing requests," do

  describe "a route with fixation configured" do

    it "should be able to allow fixation" do
      Merb::Router.prepare do
        match("/hello/:action/:id").to(:controller => "foo", :action => "fixoid").fixatable
      end

      #TODO: ugly syntax
      matched_route_for("/hello/goodbye/tagging").should be_allow_fixation
    end

    it "should be able to disallow fixation" do
      Merb::Router.prepare do
        match("/hello/:action/:id").to(:controller => "foo", :action => "fixoid")
      end

      # TODO: ugly syntax
      matched_route_for("/hello/goodbye/tagging").should_not be_allow_fixation
    end

  end

end
