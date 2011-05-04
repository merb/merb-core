# encoding: UTF-8

require 'tempfile'

module Merb
  module Test
    module RequestHelper
      # `FakeRequest` sets up a default environment which can be overridden either
      # by passing an `env` into `initialize` or using `request['HTTP_VAR'] = 'foo'`
      class FakeRequest < Request

        # @param [Hash]     env Environment options that override the defaults.
        # @param [StringIO] req The request to set as input for Rack.
        def initialize(env = {}, req = StringIO.new)
          env.environmentize_keys!
          env['rack.input'] = req
          @start       = Time.now
          super(DEFAULT_ENV.merge(env))
        end

        def self.new(env = {}, req = StringIO.new)
          super
        end

        private
        DEFAULT_ENV = Mash.new({
          'SERVER_NAME' => 'localhost',
          'PATH_INFO' => '/',
          'HTTP_ACCEPT_ENCODING' => 'gzip,deflate',
          'HTTP_USER_AGENT' => 'Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.8.0.1) Gecko/20060214 Camino/1.0',
          'SCRIPT_NAME' => '/',
          'SERVER_PROTOCOL' => 'HTTP/1.1',
          'HTTP_CACHE_CONTROL' => 'max-age=0',
          'HTTP_ACCEPT_LANGUAGE' => 'en,ja;q=0.9,fr;q=0.9,de;q=0.8,es;q=0.7,it;q=0.7,nl;q=0.6,sv;q=0.5,nb;q=0.5,da;q=0.4,fi;q=0.3,pt;q=0.3,zh-Hans;q=0.2,zh-Hant;q=0.1,ko;q=0.1',
          'HTTP_HOST' => 'localhost',
          'REMOTE_ADDR' => '127.0.0.1',
          'SERVER_SOFTWARE' => 'Mongrel 1.1',
          'HTTP_KEEP_ALIVE' => '300',
          'HTTP_REFERER' => 'http://localhost/',
          'HTTP_ACCEPT_CHARSET' => 'ISO-8859-1,utf-8;q=0.7,*;q=0.7',
          'HTTP_VERSION' => 'HTTP/1.1',
          'REQUEST_URI' => '/',
          'SERVER_PORT' => '80',
          'GATEWAY_INTERFACE' => 'CGI/1.2',
          'HTTP_ACCEPT' => 'text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5',
          'HTTP_CONNECTION' => 'keep-alive',
          'REQUEST_METHOD' => 'GET'
        }) unless defined?(DEFAULT_ENV)
      end

      # CookieJar keeps track of cookies in a simple Mash.
      class CookieJar < Mash

        # @param [Merb::Request, Merb::FakeRequest] request The controller request.
        def update_from_request(request)
          request.cookies.each do |key, value|
            if value.blank?
              self.delete(key)
            else
              self[key] = Merb::Parse.unescape(value)
            end
          end
        end

      end

      # Extend a Rack response array with controller-like methods
      #
      # @example
      #   r = [200, {'X-Pet' => 'Dog'}, "Woof!"]
      #   r.extend FakeControllerDuck
      #   r.body
      #   #=> "Woof!"
      module FakeControllerDuck
        def status
          self[0].to_i
        end

        def headers
          self[1]
        end

        def body
          self[2]
        end
      end

      # Return a `FakeRequest` built with provided parameters.
      #
      # @note If you pass a post body, the content-type will be set to URL-encoded.
      #
      # @param [Hash] env A hash of environment keys to be merged into the default list.
      # @param [Hash] opt A hash of options.
      # @option opt [String] :post_body The post body for the request.
      # @option opt [String] :req
      #   The request string. This will only be used if `:post_body` is left out.
      #
      # @return [FakeRequest] A Request object that is built based on the parameters.
      #
      # @api public
      # @deprecated
      def fake_request(env = {}, opt = {})
        if opt[:post_body]
          req = opt[:post_body]
          env[:content_type] ||= "application/x-www-form-urlencoded"
        else
          req = opt[:req]
        end
        FakeRequest.new(env, StringIO.new(req || ''))
      end

      # Dispatches an action to the given class. This bypasses the router and is
      # suitable for unit testing of controllers.
      #
      # @note Does not use routes.
      #
      # @param controller_klass (see #dispatch_request)
      # @param action (see #dispatch_request)
      # @param params (see #build_request)
      # @param env (see #build_request)
      # @param &blk (see #dispatch_request)
      #
      # @example
      #   dispatch_to(MyController, :create, :name => 'Homer' ) do |controller|
      #     controller.stub!(:current_user).and_return(@user)
      #   end
      #
      # @see Merb::Test::RequestHelper#fake_request
      #
      # @api public
      # @deprecated Deprecation note questionable.
      def dispatch_to(controller_klass, action, params = {}, env = {}, &blk)
        params = merge_controller_and_action(controller_klass, action, params)
        dispatch_request(build_request(params, env), controller_klass, action.to_s, &blk)
      end

      # Keep track of cookie values in CookieJar within the context of the
      # block; you need to set this up for specific controllers.
      #
      # @param [Array<Class>] controller_classes
      #   {Controller} classes to operate on in the context of the block.
      # @param &blk
      #   The context to operate on; optionally accepts the cookie jar as an argument.
      #
      # @api public
      # @deprecated
      def with_cookies(*controller_classes, &blk)
        cookie_jar = CookieJar.new
        before_cb = lambda { |c| c.cookies.update(cookie_jar) }
        after_cb  = lambda { |c| cookie_jar.update_from_request(c.request) }
        controller_classes.each do |klass|
          klass._before_dispatch_callbacks << before_cb
          klass._after_dispatch_callbacks  << after_cb
        end
        blk.arity == 1 ? blk.call(cookie_jar) : blk.call
        controller_classes.each do |klass|
          klass._before_dispatch_callbacks.delete before_cb
          klass._after_dispatch_callbacks.delete after_cb
        end
      end

      # Dispatches an action to the given class and using HTTP Basic Authentication
      # This bypasses the router and is suitable for unit testing of controllers.
      #
      # @note Does not use routes.
      #
      # @param (see #dispatch_to)
      # @param [String] username The username.
      # @param [String] password The password.
      #
      # @example
      #   dispatch_with_basic_authentication_to(MyController, :create, 'Fred', 'secret', :name => 'Homer' ) do |controller|
      #     controller.stub!(:current_user).and_return(@user)
      #   end
      #
      # @api public
      # @deprecated
      def dispatch_with_basic_authentication_to(controller_klass, action, username, password, params = {}, env = {}, &blk)
        env["X_HTTP_AUTHORIZATION"] = "Basic #{Base64.encode64("#{username}:#{password}")}"

        params = merge_controller_and_action(controller_klass, action, params)
        dispatch_request(build_request(params, env), controller_klass, action.to_s, &blk)
      end

      # @api private
      def merge_controller_and_action(controller_klass, action, params)
        params[:controller] = controller_klass.name.underscore
        params[:action]     = action.to_s

        params
      end

      # Prepares and returns a request suitable for dispatching with
      # {#dispatch_request dispatch_request}. If you don't need to modify the
      # request object before dispatching (e.g. to add cookies), you probably
      # want to use {#dispatch_to dispatch_to} instead.
      #
      # @note Does not use routes.
      #
      # @param [Hash] params
      #   An optional hash that will end up as params in the controller instance.
      # @param [Hash] env
      #   An optional hash that is passed to the fake request. Any request options
      #   should go here including `:req` or `:post_body` for setting the request
      #   body itself.
      #
      # @example
      #   req = build_request(:id => 1)
      #   req.cookies['app_cookie'] = "testing"
      #   dispatch_request(req, MyController, :edit)
      #
      # @see Merb::Test::RequestHelper#fake_request
      #
      # @api public
      # @deprecated
      def build_request(params = {}, env = {})
        params             = Merb::Parse.params_to_query_string(params)

        query_string = env[:query_string] || env['QUERY_STRING']
        env[:query_string] = query_string ? "#{query_string}&#{params}" : params

        post_body = env[:post_body] || env['POST_BODY']
        fake_request(env, { :post_body => post_body, :req => env[:req] })
      end


      # A generic request that checks the router for the controller and action.
      # This request goes through Merb::Router and finishes at the controller.
      #
      # @note Uses Routes.
      #
      # @param [String] path The path that should go to the router as the
      #   request uri.
      # @param [#to_s] method Request method, e.g, `:get`, `"PUT"`, ...
      # @param [Hash] params
      #   An optional hash that will end up as params in the controller instance.
      # @param [Hash] env
      #   An optional hash that is passed to the fake request. Any request options
      #   should go here.
      # @param &blk
      #   The controller is yielded to the block provided for actions *prior* to
      #   the action being dispatched.
      #
      # @example
      #   request(path, { :name => 'Homer' }, { :request_method => "PUT" }) do |controller|
      #     controller.stub!(:current_user).and_return(@user)
      #   end
      #
      # @return [#status, #headers, #body] A somewhat controller-like duck
      #   that might be a Rack response or a proper Controller instance.
      #
      # @api plugin
      def mock_request(path, method = :get, params = {}, env= {}, &block)
        if method.is_a? Hash
          env = params
          params = method
          method = params.delete(:request_method)
        end

        env[:request_method]  = (method || "GET").to_s.upcase
        env[:request_uri], env[:query_string] = path.split('?')

        multipart = env.delete(:test_with_multipart)

        request = build_request(params, env)

        opts = check_request_for_route(request) # Check that the request will be routed correctly

        unless opts.is_a?(Array)
          # should be a parameter Hash
          controller_name = (opts[:namespace] ? opts.delete(:namespace) + '/' : '') + opts.delete(:controller)
          klass = controller_name.underscore.camelize.constantize

          action = opts.delete(:action).to_s
          params.merge!(opts)

          if multipart.nil?
            dispatch_to(klass, action, params, env, &block)
          else
            dispatch_multipart_to(klass, action, params, env, &block)
          end
        else
          # likely a Rack response
          opts.extend FakeControllerDuck
        end
      end


      # The workhorse for the dispatch_to helpers.
      #
      # @param [Merb::Test::RequestHelper::FakeRequest, Merb::Request] request
      #   A request object that has been setup for testing.
      # @param [Class] controller_klass
      #   The class object of the {Controller} to dispatch the action to.
      # @param action (see Merb::Controller#_dispatch)
      # @param &blk
      #   The controller is yielded to the block provided for actions *prior* to
      #   the action being dispatched.
      #
      # @yieldparam [Controller] controller
      #
      # @return An instance of `controller_klass` based on the parameters.
      #
      # @note Does not use routes.
      #
      # @api public
      # @deprecated
      def dispatch_request(request, controller_klass, action, &blk)
        controller = controller_klass.new(request)
        yield controller if block_given?
        controller._dispatch(action)

        Merb.logger.info controller._benchmarks.inspect
        Merb.logger.flush

        controller
      end

      # Checks to see that a request is routable.
      #
      # @param [Merb::Test::RequestHelper::FakeRequest, Merb::Request] request
      #   The request object to inspect.
      #
      # @return [Hash] The parameters built based on the matching route.
      #
      # @raise [Merb::ControllerExceptions::BadRequest]
      #   No matching route was found.
      #
      # @api plugin
      # @deprecated
      def check_request_for_route(request)
        match =  ::Merb::Router.route_for(request)
        if match[0].nil? && match[1].empty?
          raise ::Merb::ControllerExceptions::BadRequest, "No routes match the request. Request uri: #{request.uri}"
        else
          match[1]
        end
      end # check_request_for_route
    end # RequestHelper
  end # Test
end # Merb
