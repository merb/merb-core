# encoding: UTF-8

module Merb::Test::Rspec::RouteMatchers

  class RouteToMatcher

    # @param [Class, String] klass_or_name
    #   The controller class or class name to match routes for.
    # @param [#to_s] action The name of the action to match routes for.
    def initialize(klass_or_name, action)
      @expected_controller = Class === klass_or_name ? klass_or_name.name : klass_or_name
      @expected_action = action.to_s
    end

    # @param [Hash] target The route parameters to match.
    #
    # @return [Boolean] True if the controller action and parameters match.
    def matches?(target)
      @target_env = target.dup
      @target_controller, @target_action = @target_env.delete(:controller).to_s, @target_env.delete(:action).to_s

      @target_controller = "#{target.delete(:namespace)}::#{@target_controller}" if target.has_key?(:namespace)

      @expected_controller.underscore == @target_controller.underscore && @expected_action == @target_action && match_parameters(@target_env)
    end

    # @param [Hash] target The route parameters to match.
    #
    # @return [Boolean]
    #   True if the parameter matcher created with #with matches or if no
    #   parameter matcher exists.
    def match_parameters(target)
      @parameter_matcher.nil? ? true : @parameter_matcher.matches?(target)
    end

    # Creates a new parameter matcher.
    #
    # #### Alternatives
    # If `parameters` is an object, then a new expected hash will be constructed
    # with the key `:id` set to `parameters.to_param`.
    #
    # @param [Hash, #to_param] parameters The parameters to match.
    #
    # @return [RouteToMatcher] This matcher.
    def with(parameters)
      @parameter_matcher = ParameterMatcher.new(parameters)

      self
    end

    # @return [String] The failure message.
    def failure_message
      "expected the request to route to #{@expected_controller.camelize}##{@expected_action}#{expected_parameters_message}, but was #{@target_controller.camelize}##{@target_action}#{actual_parameters_message}"
    end

    # @return [String] The failure message to be displayed in negative matches.
    def negative_failure_message
      "expected the request not to route to #{@expected_controller.camelize}##{@expected_action}#{expected_parameters_message}, but it did"
    end

    def expected_parameters_message
      " with #{@parameter_matcher.expected.inspect}" if @parameter_matcher
    end

    def actual_parameters_message
      " with #{(@parameter_matcher.actual || {}).inspect}" if @parameter_matcher
    end
  end

  class ParameterMatcher
    attr_accessor :expected, :actual

    # A new instance of `ParameterMatcher`
    #
    # #### Alternatives
    # If `hash_or_object` is an object, then a new expected hash will be
    # constructed with the key `:id` set to `hash_or_object.to_param`.
    #
    # @param [Hash, #to_param] hash_or_object The parameters to match.
    def initialize(hash_or_object)
      @expected = {}
      case hash_or_object
      when Hash then @expected = hash_or_object
      else @expected[:id] = hash_or_object.to_param
      end
    end

    # @param [Hash] parameter_hash The route parameters to match.
    #
    # @return [Boolean] True if the route parameters match the expected ones.
    def matches?(parameter_hash)
      @actual = parameter_hash.dup.except(:controller, :action)

      return @actual.empty? if @expected.empty?
      @expected.all? {|(k, v)| @actual.has_key?(k) && @actual[k] == v}
    end

    # @return [String] The failure message.
    def failure_message
      "expected the route to contain parameters #{@expected.inspect}, but instead contained #{@actual.inspect}"
    end

    # @return [String] The failure message to be displayed in negative matches.
    def negative_failure_message
      "expected the route not to contain parameters #{@expected.inspect}, but it did"
    end
  end

  # Passes when the actual route parameters match the expected controller class
  # and controller action. Exposes a {Merb::Test::Rspec::RouteMatchers::RouteToMatcher#with with}
  # method for specifying parameters.
  #
  # @param [Class, String] klass_or_name
  #   The controller class or class name to match routes for.
  # @param [#to_s] action The name of the action to match routes for.
  #
  # @example
  #   # Passes if a GET request to "/" is routed to the Widgets controller's
  #   # index action.
  #   request_to("/", :get).should route_to(Widgets, :index)
  #
  #   # Use the 'with' method for parameter checks
  #   request_to("/123").should route_to(widgets, :show).with(:id => "123")
  def route_to(klass_or_name, action)
    RouteToMatcher.new(klass_or_name, action)
  end
end
