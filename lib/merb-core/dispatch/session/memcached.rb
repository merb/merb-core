# encoding: UTF-8

module Merb

  # Sessions stored in memcached.
  #
  # Requires setup in your `init.rb`.
  #
  # This for the `memcache-client` gem:
  #
  #     Merb::BootLoader.after_app_loads do
  #       require 'memcache'
  #       Merb::MemcacheSession.store = 
  #          MemCache.new('127.0.0.1:11211', :namespace => 'my_app')
  #     end
  #
  # Or this for the `memcached` gem:
  #
  #     Merb::BootLoader.after_app_loads do
  #       require 'memcache'
  #       Merb::MemcacheSession.store = 
  #          Memcached.new('127.0.0.1:11211', :namespace => 'my_app')
  #     end
  #
  # @see SessionStoreContainer
  
  class MemcacheSession < SessionStoreContainer

    # The session store type
    self.session_store_type = :memcache
    
  end
  
  module MemcacheStore
    
    # Make the Memcached gem conform to the SessionStoreContainer interface


    # @api private
    def retrieve_session(session_id)
      get("session:#{session_id}")
    end

    # @api private
    def store_session(session_id, data)
      set("session:#{session_id}", data)
    end

    # @api private
    def delete_session(session_id)
      delete("session:#{session_id}")
    end
    
  end
  
end

# For the memcached gem.
class Memcached
  include Merb::MemcacheStore
end

# For the memcache-client gem.
class MemCache
  include Merb::MemcacheStore
end
