# encoding: UTF-8

module Merb::Test::Rspec::ControllerMatchers

  class BeRedirect
    # @param [Fixnum, #status] target
    #   Either the status code or a controller with a status code.
    #
    # @return [Boolean] True if the status code is in the range 300..305 or 307.
    def matches?(target)
      @target = target
      [307, *(300..305)].include?(target.respond_to?(:status) ? target.status : target)
    end

    # @return [String] The failure message.
    def failure_message
      "expected#{inspect_target} to redirect"
    end

    # @return [String] The failure message to be displayed in negative matches.
    def negative_failure_message
      "expected#{inspect_target} not to redirect"
    end

    # @return [String] The controller and action name.
    def inspect_target
      " #{@target.controller_name}##{@target.action_name}" if @target.respond_to?(:controller_name) && @target.respond_to?(:action_name)
    end
  end

  class BeError
    def initialize(expected)
      @expected = expected
    end

    def matches?(target)
      @target = target
      @target.request.exceptions &&
        @target.request.exceptions.first.is_a?(@expected)
    end

    def failure_message
      "expected #{@target} to be a #{@expected} error, but it was " <<
        @target.request.exceptions.first.inspect
    end

    def negative_failure_message
      "expected #{@target} not to be a #{@expected} error, but it was"
    end
  end

  def be_error(expected)
    BeError.new(expected)
  end

  class Provide

    # @param [Symbol] expected A format to check
    def initialize(expected)
      @expected = expected
    end

    # @param [Class, Controller] target A {Controller} class or instance
    #
    # @return [Boolean] True if the formats provided by the target controller/class include the expected
    def matches?(target)
      @target = target
      provided_formats.include?( @expected )
    end

    # @return [String] The failure message.
    def failure_message
      "expected #{@target.name} to provide #{@expected}, but it doesn't"
    end

    # @return [String] The failure message to be displayed in negative matches.
    def negative_failure_message
      "expected #{@target.name} not to provide #{@expected}, but it does"
    end

    # @return [Array<Symbol>] The formats the expected provides
    def provided_formats
      @target.class_provided_formats
    end
  end

  # Passes if the controller actually provides the target format
  #
  # @param [Symbol] expected A format to check
  #
  # @example
  #   ControllerClass.should provide( :html )
  #   controller_instance.should provide( :xml )
  def provide( expected )
    Provide.new( expected )
  end
end
