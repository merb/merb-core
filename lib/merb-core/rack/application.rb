# encoding: UTF-8

module Merb
  module Rack
    class Application

      # The main rack application call method.  This is the entry point from rack (and the webserver)
      # to your application.
      #
      # @param [Hash] env A rack request of parameters.
      #
      # @return [Array] A rack response of `[#to_i, Hash, #each]`
      #
      # @api private
      def call(env)
        rack_response =
          begin
            ret = ::Merb::Dispatcher.handle(Merb::Request.new(env))
            Merb.logger.info Merb::Const::DOUBLE_NEWLINE
            Merb.logger.flush
            ret
          rescue Object => e
            [
              500,
              {Merb::Const::CONTENT_TYPE => Merb::Const::TEXT_SLASH_HTML},
              e.message + Merb::Const::BREAK_TAG + e.backtrace.join(Merb::Const::BREAK_TAG)
            ]
          end

        # unless controller.headers[Merb::Const::DATE]
        #   require "time"
        #   controller.headers[Merb::Const::DATE] = Time.now.rfc2822.to_s
        # end

        # Rack requires the body to respond to #each
        unless rack_response[2].respond_to? :each
          rack_response[2] = Merb::Rack::StreamWrapper.new(rack_response[2])
        end

        rack_response
      end

      # Determines whether this request is a "deferred_action", usually a long request.
      # Rack uses this method to determine whether to use an evented request or a deferred
      # request in evented rack handlers.
      #
      # @param [Hash] env The rack request
      #
      # @return [Boolean] True if the request should be deferred.
      #
      # @api private
      def deferred?(env)
        path = env[Merb::Const::PATH_INFO] ? env[Merb::Const::PATH_INFO].chomp(Merb::Const::SLASH) : Merb::Const::EMPTY_STRING
        if path =~ Merb.deferred_actions
          Merb.logger.info! "Deferring Request: #{path}"
          true
        else
          false
        end
      end # deferred?(env)
    end # Application
  end # Rack
end # Merb
