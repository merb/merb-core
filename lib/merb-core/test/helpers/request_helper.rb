# encoding: UTF-8

require "rack"

module Merb
  module Test
    module RequestHelper
      def describe_request(rack)
        "a #{rack.original_env[:method] || rack.original_env["REQUEST_METHOD"] || "GET"} to '#{rack.url}'"
      end

      def describe_input(input)
        if input.respond_to?(:controller_name)
          "#{input.controller_name}##{input.action_name}"
        elsif input.respond_to?(:original_env)
          describe_request(input)
        else
          input
        end
      end

      def status_code(input)
        input.respond_to?(:status) ? input.status : input
      end
    end
  end
end
