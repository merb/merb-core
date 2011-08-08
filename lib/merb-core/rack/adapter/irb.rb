# encoding: UTF-8

module Merb
  module Rack
    class Console
      # @param (see Merb::Router#url)
      #
      # @api public
      def url(name, *args)
        args << {}
        Merb::Router.url(name, *args)
      end

      # @param (see Merb::Router#resource)
      #
      # @api public
      def resource(*args)
        args << {}
        Merb::Router.resource(*args)
      end

      # Reloads classes using `Merb::BootLoader::ReloadClasses`.
      # @api public
      def reload!
        Merb::BootLoader::ReloadClasses.reload!
      end

      # Returns a request for a specific URL and method.
      # @api public
      def route_to(url, method = :get, env_overrides = {})
        request_env = ::Rack::MockRequest.env_for(url)
        request_env["REQUEST_METHOD"] = method.to_s
        Merb::Router.route_for(Merb::Request.new(request_env.merge(env_overrides)))
      end

      # Prints all routes for the application.
      # @api public
      def show_routes
        seen = []
        unless Merb::Router.named_routes.empty?
          puts "==== Named routes"
          Merb::Router.named_routes.each do |name,route|
            # something weird happens when you combine sprintf and irb
            puts "Helper     : #{name}"
            meth = $1.upcase if route.conditions[:method].to_s =~ /(get|post|put|delete)/
            puts "HTTP method: #{meth || 'GET'}"
            puts "Route      : #{route}"
            puts "Params     : #{route.params.inspect}"
            puts
            seen << route
          end
        end
        puts "==== Anonymous routes"
        (Merb::Router.routes - seen).each do |route|
          meth = $1.upcase if route.conditions[:method].to_s =~ /(get|post|put|delete)/
          puts "HTTP method: #{meth || 'GET'}"
          puts "Route      : #{route}"
          puts "Params     : #{route.params.inspect}"
          puts
        end
        nil
      end

      # Starts a sandboxed session (delegates to any `Merb::Orms::*` modules).
      #
      # An ORM should implement `Merb::Orms::MyOrm#open_sandbox!` to support this.
      # Usually this involves starting a transaction.
      # @api public
      def open_sandbox!
        puts "Loading #{Merb.environment} environment in sandbox (Merb #{Merb::VERSION})"
        puts "Any modifications you make will be rolled back on exit"
        orm_modules.each { |orm| orm.open_sandbox! if orm.respond_to?(:open_sandbox!) }
      end

      # Ends a sandboxed session (delegates to any `Merb::Orms::*` modules).
      #
      # An ORM should implement `Merb::Orms::MyOrm#close_sandbox!` to support this.
      # Usually this involves rolling back a transaction.
      # @api public
      def close_sandbox!
        orm_modules.each { |orm| orm.close_sandbox! if orm.respond_to?(:close_sandbox!) }
        puts "Modifications have been rolled back"
      end

      # Explicitly show logger output during IRB session
      # @api public
      def trace_log!
        Merb.logger.auto_flush = true
      end

      private

      # @return [Array] All `Merb::Orms::*` modules.
      # @api private
      def orm_modules
        if Merb.const_defined?('Orms')
          Merb::Orms.constants.map { |c| Merb::Orms::const_get(c) }
        else
          []
        end
      end

    end

    class Irb
      # @param [Hash] opts
      #   Options for IRB. Currently this is not used by the IRB adapter.
      #
      # @note If the `.irbrc` file exists, it will be loaded into the IRBRC
      #   environment variable.
      #
      # @api plugin
      def self.start(opts={})
        m = Merb::Rack::Console.new
        m.extend Merb::Test::RequestHelper
        m.extend ::Webrat::Methods if defined?(::Webrat)
        Object.send(:define_method, :merb) { m }
        ARGV.clear # Avoid passing args to IRB
        m.open_sandbox! if sandboxed?
        require 'irb'

        # suppress errors when running without readline support
        begin
          require 'irb/completion'
        rescue
        end

        if File.exists? ".irbrc"
          ENV['IRBRC'] = ".irbrc"
        end
        IRB.start
        at_exit do merb.close_sandbox! if sandboxed? end
        exit
      end

      private

      # @api private
      def self.sandboxed?
        Merb::Config[:sandbox]
      end
    end
  end
end
