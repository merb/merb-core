# encoding: UTF-8

require 'merb-core/test/test_ext/object'
require 'merb-core/test/test_ext/string'

module Merb; module Test; end; end

require 'merb-core/test/helpers'

begin
  require 'webrat'

  # Monkeypatch Webrat's Merb adapter to use our own session model
  module Webrat
    class MerbAdapter < RackAdapter
      def initialize(context=nil)
        app = if context.respond_to?(:app)
                context.app
              else
                Merb::Rack::Application.new
              end

        super(Rack::Test::Session.new(Merb::Rack::MockSession.new(app, 'example.com')))
      end
    end
  end

  Webrat.configure do |c|
    c.mode = :merb
  end
rescue LoadError => e
  if Merb.testing?
    Merb.logger.warn! "Couldn't load Webrat, so some features, like `visit' will not " \
                      "be available. Please install webrat if you want these features."
  end
end

if Merb.test_framework.to_s == "rspec"
  begin
    require 'merb-core/test/test_ext/rspec'
    require 'merb-core/test/matchers'
  rescue LoadError
    Merb.logger.warn! "You're using RSpec as a testing framework but you don't have " \
                      "the gem installed. To provide full functionality of the test " \
                      "helpers you should install it."
  end
end
