# encoding: UTF-8

module Merb
  module Rack

    class FastCGI
      # @param [Hash] opts Options for FastCGI.
      # @option opts [String] :app The application name.
      #
      # @api plugin
      def self.start(opts={})
        Merb.logger.warn!("Using FastCGI adapter")
        Merb::Server.change_privilege
        ::Rack::Handler::FastCGI.run(opts[:app], opts)
      end
    end
  end
end
