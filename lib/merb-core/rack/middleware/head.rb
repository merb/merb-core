# encoding: UTF-8

require 'rack/head'
require 'merb-core/rack/middleware'

module Merb
  module Rack

    # Merbified Rack::Head
    #
    # @see Merb::Rack::DeferrableMiddleware
    class Head < ::Rack::Head
      include Merb::Rack::DeferrableMiddleware
    end
  end
end
