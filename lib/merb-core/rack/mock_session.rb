module Merb
  module Rack
    # Extend Rack's MockSession to provide some Merb-specific functionality.
    #
    # This is a port of {Merb::Test::RequestHelper} to Rack middleware,
    # intended as a replacement for Rack::MockSession.
    #
    # To work around an inconsistency and hardcoded defaults in Rack and
    # Webrat, this adapter modifies an incoming server name '*.example.org'
    # to '*.example.com'. If you need to test cross-domain behaviour, use
    # different domains.
    #
    # Handles the following custom parameters in
    # `Merb::Config[:test_settings]`:
    #
    # * __`:cookie_jar`:__ Name of a cookie jar. When set to `nil`, cookies
    #   are disabled.
    # * __`:cookie`:__ An explicit cookie value that will be used in
    #   the request
    #
    # When `Merb::Config[:path_prefix]` is set, and the request matches the
    # prefix, it will be trimmed.
    #
    # @example [Prefix trimming]
    #  Merb::Config[:path_prefix] = '/foo'
    #  visit('/foo/bar') # will visit '/bar'
    #
    # @todo Only handles plain GET requests.
    class MockSession

      def initialize(app, host)
        @app = app
        @host = host

        @last_request = @last_response = nil
      end

      # Rack filter.
      #
      # @param [Hash] env A rack request of parameters.
      #
      # @return [Array] A rack response.
      #
      # @api public
      def call(env)
        env['PATH_INFO'] = trim_prefix(env['PATH_INFO'])

        # normalize to example.com (Rack's hardcoded default!)
        if env['SERVER_NAME'] =~ /(\A|.*\.)example\.org\Z/
          env['SERVER_NAME'] = "#{$1}example.com"
        end

        uri = URI(env['PATH_INFO'])
        uri.scheme ||= "http"
        uri.host = if env.has_key? 'SERVER_NAME'
                     env['SERVER_NAME']
                   else
                     @host
                   end

        #FIXME: disabled for now
        if false
          if env["REQUEST_METHOD"] == "POST"
            params = env.delete(:body_params) if env.key?(:body_params)
            params = env.delete(:params) if env.key?(:params) && !env.key?(:input)

            unless env.key?(:input)
              env[:input] = Merb::Parse.params_to_query_string(params)
              env["CONTENT_TYPE"] = "application/x-www-form-urlencoded"
            end
          end

          if env[:params]
            uri.query = [
              uri.query, Merb::Parse.params_to_query_string(env.delete(:params))
            ].compact.join("&")
          end
        end

        # add cookies to the request
        unless ignore_cookies?
          @__cookie_jar__ ||= Merb::Test::CookieJar.new
          jar = cookie_jar_name
          @__cookie_jar__.update(jar, uri, cookie_content) if cookie_given?
          env["HTTP_COOKIE"] = @__cookie_jar__.for(jar, uri)
        end

        @last_request = ::Rack::Request.new(env)
        app = Merb::Config[:app]
        status, headers, body = app.call(@last_request.env)

        @last_response = ::Rack::MockResponse.new(status, headers, body, env['rack.errors'].flush)

        # Webrat does that
        body.close if body.respond_to?(:close)

        # keep cookies returned from the application
        @__cookie_jar__.update(jar, uri, last_response.headers["Set-Cookie"]) unless ignore_cookies?

        Merb::Dispatcher.work_queue.size.times do
          Merb::Dispatcher.work_queue.pop.call
        end

        [@last_response.status, @last_response.headers, Merb::Rack::StreamWrapper.new(@last_response.body)]
      end

      def last_request
        raise Rack::Test::Error.new("No request yet. Request a page first.") unless @last_request
        @last_request
      end

      def last_response
        raise Rack::Test::Error.new("No response yet. Request a page first.") unless @last_response
        @last_response
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
      end

      private

      def ignore_cookies?
        Merb::Config[:test_settings] &&
          Merb::Config[:test_settings].has_key?(:cookie_jar) &&
          Merb::Config[:test_settings][:cookie_jar].nil?
      end

      def cookie_jar_name
        if Merb::Config[:test_settings]
          Merb::Config[:test_settings][:cookie_jar] || :default
        else
          :default
        end
      end

      def cookie_given?
        if Merb::Config[:test_settings]
          Merb::Config[:test_settings][:cookie] ? true : false
        else
          false
        end
      end

      def cookie_content
        Merb::Config[:test_settings][:cookie]
      end

      def trim_prefix(uri)
        if prefix = Merb::Config[:path_prefix]
          new_uri = uri.sub(/^#{Regexp.escape(prefix)}/, '')
          new_uri.empty? ? '/' : new_uri
        else
          uri
        end
      end

    end # MockSession
  end # Rack
end # Merb
