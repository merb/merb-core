# encoding: UTF-8

module Merb

  module Rack

    class Adapter

      class << self
        # Get a `Rack` adapter by id.
        #
        # @param [#to_s] id The identifier of the `Rack` adapter class to retrieve.
        #
        # @return [Class] The adapter class.
        #
        # @api private
        def get(id)
          if @adapters[id.to_s]
            @adapters[id.to_s].constantize
          else
            Merb.fatal! "The adapter #{id} did not exist"
          end
        end

        # Registers a new `Rack` adapter.
        #
        # @param [Array] ids Identifiers by which this adapter is recognized by.
        # @param [Class] adapter_class The `Rack` adapter class.
        #
        # @api plugin
        def register(ids, adapter_class)
          @adapters ||= Hash.new
          ids.each { |id| @adapters[id] = "Merb::Rack::#{adapter_class}" }
        end
      end # class << self

    end # Adapter

    # Register some Rack adapters
    Adapter.register %w{ebb},            :Ebb
    Adapter.register %w{emongrel},       :EventedMongrel
    Adapter.register %w{fastcgi fcgi},   :FastCGI
    Adapter.register %w{irb},            :Irb
    Adapter.register %w{mongrel},        :Mongrel
    Adapter.register %w{runner},         :Runner
    Adapter.register %w{smongrel swift}, :SwiftipliedMongrel
    Adapter.register %w{thin},           :Thin
    Adapter.register %w{thin-turbo tt},  :ThinTurbo
    Adapter.register %w{webrick},        :WEBrick

  end # Rack
end # Merb
