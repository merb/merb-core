# encoding: UTF-8

module Merb
  
  class Router
    # Cache procs for future reference in eval statement.
    # @api private
    class CachedProc
      @@index = 0
      @@list = []

      # @api private
      attr_accessor :cache, :index

      # @param [Proc] cache The block of code to cache.
      #
      # @api private
      def initialize(cache)
        @cache, @index = cache, CachedProc.register(self)
      end

      # @return [String] The CachedProc object in a format embeddable
      #   within a string.
      #
      # @api private
      def to_s
        "CachedProc[#{@index}].cache"
      end

      class << self

        # @param [CachedProc] cached_code The cached code to register.
        #
        # @return [Fixnum] The index of the newly registered CachedProc.
        #
        # @api private
        def register(cached_code)
          CachedProc[@@index] = cached_code
          @@index += 1
          @@index - 1
        end

        # Sets the cached code for a specific index.
        #
        # @param [Fixnum] index The index of the cached code to set.
        # @param [CachedProc] code The cached code to set.
        #
        # @api private
        def []=(index, code) @@list[index] = code end

        # @param [Fixnum] index The index of the cached code to retrieve.
        #
        # @param [CachedProc] The cached code at index.
        #
        # @api private
        def [](index) @@list[index] end
      end
    end # CachedProc
  end
end
