# encoding: UTF-8

module Merb
  class Router

    # Route helpers for defining RESTful routes.
    # @example Single resources:
    #     r.resource :account # will result in the typical RESTful CRUD
    #       # shows new resource form
    #       # GET     /account/new                :action => "new"
    #
    #       # creates resource
    #       # POST    /account/?(\.:format)?,     :action => "create"
    #
    #       # shows resource
    #       # GET     /account/(\.:format)?       :action => "show"
    #
    #       # shows edit form
    #       # GET     /account//edit           :action => "edit"
    #
    #       # updates resource
    #       # PUT     /account/(\.:format)?       :action => "update"
    #
    #       # shows deletion confirmation page
    #       # GET     /account//delete         :action => "delete"
    #
    #       # destroys resources
    #       # DELETE  /account/(\.:format)?       :action => "destroy"
    #
    # @example Resource collections:
    #    r.resources :posts # will result in the typical RESTful CRUD
    #      # lists resources
    #      # GET     /posts/?(\.:format)?      :action => "index"
    #      # GET     /posts/index(\.:format)?  :action => "index"
    #
    #      # shows new resource form
    #      # GET     /posts/new                :action => "new"
    #
    #      # creates resource
    #      # POST    /posts/?(\.:format)?,     :action => "create"
    #
    #      # shows resource
    #      # GET     /posts/:id(\.:format)?    :action => "show"
    #
    #      # shows edit form
    #      # GET     /posts/:id/edit        :action => "edit"
    #
    #      # updates resource
    #      # PUT     /posts/:id(\.:format)?    :action => "update"
    #
    #      # shows deletion confirmation page
    #      # GET     /posts/:id/delete      :action => "delete"
    #
    #      # destroys resources
    #      # DELETE  /posts/:id(\.:format)?    :action => "destroy"
    #
    # @example Nesting resources:
    #     r.resources :posts do |posts|
    #       posts.resources :comments
    #     end
    #
    # @example Passing a block, and using the `:namespace` and `controller` options:
    #     r.resource :account, :namespace => "admin" do |account|
    #       account.resources :preferences, :controller => "settings"
    #     end
    module Resources
      # Define a collection of RESTful resources. It yields to a block
      # for child routes.
      #
      # @param [String, Symbol] name The name of the resources.
      # @param [Hash] options<Hash> Overrides and parameters to be
      #   associated with the route.
      # @option options [#to_s] :namespace
      #   The namespace for this route.
      # @option options [#to_s] :name_prefix
      #   A prefix for the named routes. If a namespace is passed and there
      #   isn't a name prefix, the namespace will become the prefix.
      # @option options [#to:s] :controller
      #   The controller for this route
      # @option options [#to_s] :collection
      #   Special settings for the collections routes
      # @option options [Hash] :member
      #   Special settings and resources related to a specific member of
      #   this resource.
      # @option options [Symbol, Array] :identify
      #   The method(s) that should be called on the object before inserting
      #   it into an URL.
      # @option options [Array] :keys
      #   A list of the keys to be used instead of :id with the resource
      #   in the order of the url.
      # @option options [Symbol] :singular
      #   The given name is assumed to be the plural form. If the inflector
      #   fails to produce a suitable singular, specify one here.
      #
      # @yieldparam [Behavior] next_level The child behavior.
      #
      # @return [Array] Routes which will define the specified RESTful
      #   collection of resources
      #
      # @api public
      def resources(name, *args, &block)
        name       = name.to_s
        options    = extract_options_from_args!(args) || {}
        match_opts = options.except(*resource_options)
        options    = options.slice(*resource_options)
        singular   = options[:singular] ? options[:singular].to_s : ActiveSupport::Inflector.singularize(name)
        klass_name = args.first ? args.first.to_s : singular.camelize
        keys       = options.delete(:keys) || options.delete(:key)
        params     = { :controller => options.delete(:controller) || name }
        collection = options.delete(:collection) || {}
        member     = { :edit => :get, :delete => :get }.merge(options.delete(:member) || {})
        
        # Use the identifier for the class as a default
        begin
          if klass = klass_name.constantize
            keys ||= options[:identify]
            keys ||= @identifiers[klass]
          elsif options[:identify]
            raise Error, "The constant #{klass_name} does not exist, please specify the constant for this resource"
          end
        rescue NameError => e
          Merb.logger.debug!("Could not find resource model #{klass_name}")
        end
        
        keys = [ keys || :id ].flatten
        

        # Try pulling :namespace out of options for backwards compatibility
        options[:name_prefix]       ||= nil # Don't use a name_prefix if not needed
        options[:resource_prefix]   ||= nil # Don't use a resource_prefix if not needed
        options[:controller_prefix] ||= options.delete(:namespace)

        context = options[:identify]
        context = klass && options[:identify] ? identify(klass => options.delete(:identify)) : self
        context.namespace(name, options).to(params) do |resource|
          root_keys = keys.map { |k| ":#{k}" }.join("/")
          
          # => index
          resource.match("(/index)(.:format)", :method => :get).to(:action => "index").
            name(name).register_resource(name)
            
          # => create
          resource.match("(.:format)", :method => :post).to(:action => "create")
          
          # => new
          resource.match("/new(.:format)", :method => :get).to(:action => "new").
            name("new", singular).register_resource(name, "new")

          # => user defined collection routes
          collection.each_pair do |action, method|
            action = action.to_s
            resource.match("/#{action}(.:format)", :method => method).to(:action => "#{action}").
              name(action, name).register_resource(name, action)
          end

          if block_given?
            parent_keys = keys.map do |k|
              k == :id ? "#{singular}_id".to_sym : k
            end
            
            nested_keys = parent_keys.map { |k| ":#{k}" }.join("/")

            nested_match_opts = match_opts.except(:id)
            nested_match_opts["#{singular}_id".to_sym] = match_opts[:id] if match_opts[:id]
            
            # Procs for building the extra collection/member resource routes
            builders    = {}
            
            builders[:collection] = lambda do |action, to, method|
              resource.match("/#{action}(.:format)", match_opts.merge(:method => method)).
                to(:action => to).name(action, name).register_resource(name, action)
            end
            
            builders[:member] = lambda do |action, to, method|
              resource.match("/#{root_keys}/#{action}(.:format)", match_opts.merge(:method => method)).
                to(:action => to).name(action, singular).register_resource(klass_name, action, :identifiers => keys)
            end
            
            resource.options(:name_prefix => singular, :resource_prefix => klass_name, :parent_keys => parent_keys).
              match("/#{nested_keys}", nested_match_opts).resource_block(builders, &block)
          end

          # => show
          resource.match("/#{root_keys}(.:format)", match_opts.merge(:method => :get)).to(:action => "show").
            name(singular).register_resource(klass_name, :identifiers => keys)

          # => user defined member routes
          member.each_pair do |action, method|
            action = action.to_s
            resource.match("/#{root_keys}/#{action}(.:format)", match_opts.merge(:method => method)).
              to(:action => "#{action}").name(action, singular).register_resource(klass_name, action, :identifiers => keys)
          end

          # => update
          resource.match("/#{root_keys}(.:format)", match_opts.merge(:method => :put)).
            to(:action => "update")

          # => destroy
          resource.match("/#{root_keys}(.:format)", match_opts.merge(:method => :delete)).
            to(:action => "destroy")

        end # namespace
      end # resources

      # Define a singular RESTful resource. It yields to a block for child
      # routes.
      #
      # @param [String, Symbol] name The name of the resource.
      # @param [Hash] options Overrides and parameters to be
      #   associated with the route.
      # @option options [#to_s] :namespace
      #   The namespace for this route.
      # @option options [#to_s] :name_prefix
      #   A prefix for the named routes. If a namespace is passed and there
      #   isn't a name prefix, the namespace will become the prefix.
      # @option options [#to_s] :controller
      #   The controller for this route
      #
      # @yieldparam [Behavior] next_level The child behavior.
      #
      # @return [Array] Routes which define a RESTful single resource.
      #
      # @api public
      def resource(name, *args, &block)
        name    = name.to_s
        options = extract_options_from_args!(args) || {}
        params  = { :controller => options.delete(:controller) || name.pluralize }
        member  = { :new => :get, :edit => :get, :delete => :get }.merge(options.delete(:member) || {})

        options[:name_prefix]       ||= nil # Don't use a name_prefix if not needed
        options[:resource_prefix]   ||= nil # Don't use a resource_prefix if not needed
        options[:controller_prefix] ||= options.delete(:namespace)

        self.namespace(name, options).to(params) do |resource|
          # => show
          
          resource.match("(.:format)", :method => :get).to(:action => "show").
            name(name).register_resource(name)
            
          # => create
          resource.match("(.:format)", :method => :post).to(:action => "create")
            
          # => update
          resource.match("(.:format)", :method => :put).to(:action => "update")
            
          # => destroy
          resource.match("(.:format)", :method => :delete).to(:action => "destroy")
          
          member.each_pair do |action, method|
            action = action.to_s
            resource.match("/#{action}(.:format)", :method => method).to(:action => action).
              name(action, name).register_resource(name, action)
          end

          if block_given?
            builders = {}
            
            builders[:member] = lambda do |action, to, method|
              resource.match("/#{action}(.:format)", :method => method).to(:action => to).
                name(action, name).register_resource(name, action)
            end
            
            resource.options(:name_prefix => name, :resource_prefix => name).
              resource_block(builders, &block)
          end
        end
      end
      
    protected
    
      # @api private
      def register_resource(*key)
        options     = extract_options_from_args!(key) || {}
        key         = [ @options[:resource_prefix], key ].flatten.compact
        identifiers = [ @options[:parent_keys], options[:identifiers] ]
        @route.resource = key
        @route.resource_identifiers = identifiers.flatten.compact.map { |id| id.to_sym }
        self
      end

      # @api private
      def resource_block(builders, &block)
        behavior = ResourceBehavior.new(builders, @proxy, @conditions, @params, @defaults, @identifiers, @options, @blocks)
        with_behavior_context(behavior, &block)
      end
      
      def resource_options
        [:singular, :keys, :key, :controller, :member, :collection, :identify,
          :name_prefix, :resource_prefix, :controller_prefix, :namespace, :path]
      end

    end # Resources
    
    class Behavior
      include Resources
    end
    
    # Adding the collection and member methods to behavior
    class ResourceBehavior < Behavior #:nodoc:
      
      # @api private
      def initialize(builders, *args)
        super(*args)
        @collection = builders[:collection]
        @member     = builders[:member]
      end
      
      # @api private
      def collection(action, options = {})
        action = action.to_s
        method = options[:method]
        to     = options[:to] || action
        @collection[action, to, method]
      end
      
      # @api private
      def member(action, options = {})
        action = action.to_s
        method = options[:method]
        to     = options[:to] || action
        @member[action, to, method]
      end
      
    end
  end
end
