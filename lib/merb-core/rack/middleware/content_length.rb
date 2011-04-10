# encoding: UTF-8

require 'rack/content_length'
require 'merb-core/rack/middleware'

module Merb
  module Rack

    # Merbified Rack::ContentLength
    #
    # @see Merb::Rack::DeferrableMiddleware
    class ContentLength < ::Rack::ContentLength
      include Merb::Rack::DeferrableMiddleware
    end
  end
end
