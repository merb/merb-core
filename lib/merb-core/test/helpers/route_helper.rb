# encoding: UTF-8

module Merb
  module Test
    module RouteHelper
      include RequestHelper

      # @see Merb::Router.url
      def url(*args)
        args << (@request_params || {})
        Merb::Router.url(*args)
      end

      # @see Merb::Router.resource
      def resource(*args)
        args << @request_params || {}
        Merb::Router.resource(*args)
      end

      # @param [#to_s]    path    The URL of the request.
      # @param [#to_sym]  method  HTTP request method.
      # @param [Hash]     env     Additional parameters for the request.
      #
      # @return [Hash] A hash containing the controller and action along with any parameters
      def request_to(path, method = :get, env = {})
        env[:request_method] ||= method.to_s.upcase
        env[:request_uri] = path

        check_request_for_route(build_request({}, env))
      end
    end
  end
end
