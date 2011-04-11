require File.expand_path(File.join(File.dirname(__FILE__), "spec_helper"))

startup_merb(:log_level => :fatal)

require File.dirname(__FILE__) / "controllers/request_controller"

module WithPathPrefixHelper
  def with_path_prefix(prefix)
    old_prefix = Merb::Config[:path_prefix]
    Merb::Config[:path_prefix] = prefix
    yield
  ensure
    Merb::Config[:path_prefix] = old_prefix
  end

  def with_test_settings(opts = {})
    overwritten = {}
    Merb::Config[:test_settings] ||= {}

    opts.each do |key, value|
      if Merb::Config[:test_settings].has_key? :key
        overwritten[key] = Merb::Config[:test_settings][key]
      end

      Merb::Config[:test_settings][key] = value
    end

    yield
  ensure
    opts.each do |key, value|
      if overwritten.has_key?(key)
        Merb::Config[:test_settings][key] = overwritten[key]
      else
        Merb::Config[:test_settings].delete(key)
      end
    end
  end
end

describe Merb::Test::RequestHelper do
  include WithPathPrefixHelper

  before(:each) do
    Merb::Controller._default_cookie_domain = "example.com"

    Merb::Router.prepare do
      with(:controller => "merb/test/request_controller") do
        match("/set/short/long/read").to(:action => "get")
        match("/:action(/:junk)", :junk => ".*").register
      end
    end
  end

  it "should remove the path_prefix configuration option" do
    with_path_prefix '/foo' do
      visit("/foo/path").should have_body('1')
    end
  end

  it "should dispatch a request using GET by defalt" do
    visit("/request_method").should have_body("Method - GET")
  end

  it "should work with have_selector" do
    visit("/document").should have_selector("div div")
  end

  it "should work with have_xpath" do
    visit("/document").should have_xpath("//div/div")
  end

  it "should work with have_content" do
    visit("/request_method").should contain("Method")
  end

  it "should persist cookies across sequential cookie setting requests" do
    visit("/counter").should have_body("1")
    visit("/counter").should have_body("2")
  end

  it "should persist cookies across requests that don't return any cookie headers" do
    visit("/counter").should have_body("1")
    visit("/void").should    have_body("Void")
    visit('/counter').should have_body("2")
  end

  it "should delete cookies from the jar" do
    visit("/counter").should have_body("1")
    visit("/delete").should  have_body("Delete")
    visit("/counter").should have_body("1")
  end

  it "should be able to disable the cookie jar" do
      with_test_settings(:cookie_jar => nil) do
        visit("/counter").should have_body("1")
        visit("/counter").should have_body("1")
      end

      visit("/counter").should have_body("1")
      visit("/counter").should have_body("2")
  end

  it "should be able to specify separate jars" do
      with_test_settings(:cookie_jar => :one) { visit("/counter").should have_body("1") }
      with_test_settings(:cookie_jar => :two) { visit("/counter").should have_body("1") }
      with_test_settings(:cookie_jar => :one) { visit("/counter").should have_body("2") }
      with_test_settings(:cookie_jar => :two) { visit("/counter").should have_body("2") }
  end

  it 'should allow a cookie to be set' do
      cookie = visit("/counter").headers['Set-Cookie']
      visit("/delete")
      with_test_settings(:cookie => cookie) { visit("/counter").should have_body("2") }
  end

  it "should respect cookie domains when no domain is explicitly set" do
    visit("http://example.com/counter").should     have_body("1")
    visit("http://www.example.com/counter").should have_body("2")
    visit("http://example.com/counter").should     have_body("3")
    visit("http://www.example.com/counter").should have_body("4")
  end

  it "should respect the domain set in the cookie" do
    visit("http://example.com/domain").should     have_body("1")
    visit("http://foo.example.com/domain").should have_body("1")
    visit("http://example.com/domain").should     have_body("1")
    visit("http://foo.example.com/domain").should have_body("2")
  end

  it "should respect the path set in the cookie" do
    visit("/path").should      have_body("1")
    visit("/path/zomg").should have_body("1")
    visit("/path").should      have_body("1")
    visit("/path/zomg").should have_body("2")
  end

  it "should use the most specific path cookie" do
    visit("/set/short")
    visit("/set/short/long")
    visit("/set/short/long/read").should have_body("/set/short/long")
  end

  it "should use the most specific path cookie even if it was defined first" do
    visit("/set/short/long")
    visit("/set/short")
    visit("/set/short/long/read").should have_body("/set/short/long")
  end

  it "should leave the least specific cookie intact when specifying a more specific path" do
    visit("/set/short")
    visit("/set/short/long/zomg/what/hi")
    visit("/set/short/long/read").should have_body("/set/short")
  end

  it "should use the most specific domain cookie" do
    pending "Does not work with Rack's MockSession" do
      visit("http://test.com/domain_set")
      visit("http://one.test.com/domain_set")
      visit("http://one.test.com/domain_get").should have_body("one.test.com")
    end
  end

  it "should keep the less specific domain cookie" do
    pending "Does not work with Rack's MockSession" do
      visit("http://www.example.com/domain_set").should be_successful
      visit("http://one.www.example.com/domain_set").should be_successful
      visit("http://www.example.com/domain_get").should have_body("www.example.com")
    end
  end

  it "should be able to handle multiple cookies" do
    visit("/multiple").should have_body("1 - 1")
    visit("/multiple").should have_body("2 - 2")
  end

  it "should respect the expiration" do
    visit("/expires").should have_body("1")
    sleep(1)
    visit("/expires").should have_body("1")
  end
end
