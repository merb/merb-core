# encoding: UTF-8

require 'merb-core/dispatch/session/container'
require 'merb-core/dispatch/session/store_container'

# Try to require SecureRandom from the Ruby 1.9.x
begin
  require 'securerandom'
rescue LoadError
end

module Merb
  class Config
    # Returns stores list constructed from
    # configured session stores (`:session_stores` config option)
    # or default one (`:session_store` config option).
    #
    # @api private
    def self.session_stores
      @session_stores ||= begin
        config_stores = Array(
          Merb::Config[:session_stores] || Merb::Config[:session_store]
        )
        config_stores.map { |name| name.to_sym }
      end
    end
  end # Config

  # The `Merb::Session` module gets mixed into {Merb::SessionContainer} to
  # allow app-level functionality (usually found in ./merb/session/session.rb)
  # for session.
  #
  # You can use this module to implement additional methods to simplify
  # building wizard-like application components, authentication frameworks,
  # etc.
  #
  # Session configuration options:
  #
  # * **`:session_id_key:`** The key by which a session value/id is
  #   retrieved; defaults to `_session_id`
  # * **`:session_expiry:`** When to expire the session cookie; by
  #   defaults, session expires when browser quits.
  # * **`:session_secret_key:`** A secret string which is used to
  #   sign/validate session data; min. 16 chars.
  # * **`:default_cookie_domain:`** The default domain to write cookies for.
  module Session    
  end

  # This is mixed into Merb::Controller on framework boot.
  module SessionMixin
    # Raised when no suitable session store has been setup.
    class NoSessionContainer < StandardError; end

    # Raised when storing more data than the available space reserved.
    class SessionOverflow < StandardError; end

    # @api private
    def self.included(base)
      # Register a callback to finalize sessions - needs to run before the cookie
      # callback extracts Set-Cookie headers from request.cookies.
      base._after_dispatch_callbacks.unshift lambda { |c| c.request.finalize_session }
    end

    # @param [String] session_store The type of session store to access.
    #
    # @return [SessionContainer] The session that was extracted from the
    #   request object.
    #
    # @api public
    def session(session_store = nil)
      request.session(session_store)
    end
    
    # Module methods


    # @return [String] A random 32 character string for use as a unique
    #   session ID.
    #
    # @api private
    def rand_uuid
      if defined?(SecureRandom)
        SecureRandom.hex(16)
      else
        values = [
          rand(0x0010000),
          rand(0x0010000),
          rand(0x0010000),
          rand(0x0010000),
          rand(0x0010000),
          rand(0x1000000),
          rand(0x1000000),
        ]
        "%04x%04x%04x%04x%04x%06x%06x" % values
      end
    end

    # Marks this session as needing a new cookie.
    #
    # @api private
    def needs_new_cookie!
      @_new_cookie = true
    end

    # Does session need new cookie?
    #
    # @return [Boolean] True if a new cookie is needed, false otherwise.
    #
    # @api private
    def needs_new_cookie?
      @_new_cookie
    end
    
    module_function :rand_uuid, :needs_new_cookie!, :needs_new_cookie?
    
    module RequestMixin

      # Adds class methods to {Merb::Request} object.
      # Sets up repository of session store types.
      # Sets the session ID key and expiry values.
      #
      # @api private
      def self.included(base)
        base.extend ClassMethods
        
        # Keep track of all known session store types.
        base.cattr_accessor :registered_session_types
        base.registered_session_types = ActiveSupport::OrderedHash.new
        base.class_attribute :_session_id_key, :_session_secret_key,
                             :_session_expiry, :_session_secure,
                             :_session_http_only, :_default_cookie_domain
        
        base._session_id_key        = Merb::Config[:session_id_key] || '_session_id'
        base._session_expiry        = Merb::Config[:session_expiry] || 0
        base._session_secret_key    = Merb::Config[:session_secret_key]
        base._session_secure        = Merb::Config[:session_secure] || false
        base._session_http_only     = Merb::Config[:session_http_only] || false
        base._default_cookie_domain = Merb::Config[:default_cookie_domain]
      end
      
      module ClassMethods

        # @param [#to_sym] name Name of the session type to register.
        # @param [String] class_name The corresponding class name.
        #
        # @note This is automatically called when {Merb::SessionContainer}
        #   is subclassed.
        #
        # @api private
        def register_session_type(name, class_name)
          self.registered_session_types[name.to_sym] = class_name
        end
        
      end

      # The default session store type.
      #
      # @api private
      def default_session_store
        Merb::Config[:session_store] && Merb::Config[:session_store].to_sym
      end

      # @return [Hash] All active session stores by type.
      #
      # @api private
      def session_stores
        @session_stores ||= {}
      end

      # Returns session container. Merb is able to handle multiple session
      # stores, hence a parameter to pick it.
      #
      # If no suitable session store type is given, it defaults to
      # cookie-based sessions.
      #
      # @param [String] session_store The type of session store to access,
      #   defaults to default_session_store.
      #
      # @return [SessionContainer]
      #   an instance of a session store extending {Merb::SessionContainer}.
      # 
      # @api public
      def session(session_store = nil)
        session_store ||= default_session_store
        if class_name = self.class.registered_session_types[session_store]
          session_stores[session_store] ||= class_name.constantize.setup(self)
        elsif fallback = self.class.registered_session_types.keys.first
          Merb.logger.warn "Session store '#{session_store}' not found. Check your configuration in init file."
          Merb.logger.warn "Falling back to #{fallback} session store."
          session(fallback)
        else
          msg = "No session store set. Set it in init file like this: c[:session_store] = 'activerecord'"
          Merb.logger.error!(msg)
          raise NoSessionContainer, msg            
        end
      end

      # @param [Merb::SessionContainer] new_session A session store instance.
      #
      # @note The session is assigned internally by its `session_store_type`
      #   key.
      #
      # @api private
      def session=(new_session)
        if self.session?(new_session.class.session_store_type)
          original_session_id = self.session(new_session.class.session_store_type).session_id
          if new_session.session_id != original_session_id
            set_session_id_cookie(new_session.session_id)
          end
        end
        session_stores[new_session.class.session_store_type] = new_session
      end

      # Whether a session has been setup
      #
      # @return [Boolean] True if the session is part of the session
      #   stores configured.
      # 
      # @api private
      def session?(session_store = nil)
        (session_store ? [session_store] : session_stores).any? do |type, store|
          store.is_a?(Merb::SessionContainer)
        end
      end

      # Teardown and/or persist the current sessions.
      #
      # @api private
      def finalize_session
        session_stores.each { |name, store| store.finalize(self) }
      end
      alias :finalize_sessions :finalize_session
      
      # Assign default cookie values
      #
      # @api private
      def default_cookies
        defaults = {}
        if route && route.allow_fixation? && params.key?(_session_id_key)
          Merb.logger.info("Fixated session id: #{_session_id_key}")
          defaults[_session_id_key] = params[_session_id_key]
        end
        defaults
      end

      # Sets session cookie value.
      #
      # Default cookie settings are taken from
      #
      # * `_session_expiry` for lifetime
      # * `_default_cookie_domain` for the domain (if specified in the
      #   configuration)
      # * `_session_secure`
      # * `_session_http_only`
      #
      # Those config settings can be overridden with the `options`
      # parameter.
      #
      # @param [String] value The value of the session cookie; either the
      #   session id or the actual encoded data.
      # @param [Hash] options Cookie options like domain, path and expired.
      # @option options (see Cookies#set_cookie)
      #
      # @api private
      def set_session_cookie_value(value, options = {})
        defaults = {}
        defaults[:expires]   = Time.now + _session_expiry if _session_expiry > 0
        defaults[:domain]    = _default_cookie_domain if _default_cookie_domain
        defaults[:secure]    = _session_secure
        defaults[:http_only] = _session_http_only
        cookies.set_cookie(_session_id_key, value, defaults.merge(options))
      end
      alias :set_session_id_cookie :set_session_cookie_value

      # @return [String] The value of the session cookie; either the
      #   session id or the actual encoded data.
      #
      # @api private
      def session_cookie_value
        cookies[_session_id_key]
      end
      alias :session_id :session_cookie_value

      # Destroy the session cookie.
      # 
      # @api private
      def destroy_session_cookie
        cookies.delete(_session_id_key)
      end
      
    end
  end
end
