# encoding: UTF-8

module Merb
  module Rack

    # Module providing delegation of the deferred? call
    #
    # Merb handles support for the deferred actions supported
    # by some evented web servers such as Thin and Ebb. To 
    # support this functionality a rack application must respond
    # to deferred? method.
    #
    # Making your middleware inherit from Merb::Rack::Middleware
    # or by including this module you'll provide neccessary
    # functionality to make this work.
    #
    # In case you need to merbify some middleware you can just
    # include this module. See merb-core/rack/middleware/head.rb or
    # merb-core/rack/middleware/content_lenght.rb.
    #
    # @see Merb::Rack::Head
    # @see Merb::Rack::ContentLength
    # @see Merb::Rack::Middleware
    module DeferrableMiddleware
      
      # @overridable
      # @api plugin
      def deferred?(env)
        @app.deferred?(env) if @app.respond_to?(:deferred?)
      end
    end

    # Base class for the Merb middlewares
    #
    # When you need to write your own middleware for Merb you should
    # this class as a base class to make sure middleware has expected
    # interface.
    #
    # In case you need to Merbify some middleware you can use
    # Merb::Rack::DeferrableMiddleware module to add deferred
    # actions support.
    #
    # @see Merb::Rack::DeferrableMiddleware
    class Middleware
      include Merb::Rack::DeferrableMiddleware

      # @overridable
      # @api plugin
      def initialize(app)
        @app = app
      end

      # @overridable
      # @api plugin
      def call(env)
        @app.call(env)
      end
    end
  end
end
