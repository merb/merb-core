# encoding: UTF-8

require 'rspec'

module RSpec
  module Matchers
    def fail
      raise_error(RSpec::Expectations::ExpectationNotMetError)
    end

    def fail_with(message)
      raise_error(RSpec::Expectations::ExpectationNotMetError, message)
    end
  end
end

module Merb
  module Test
    def self.add_helpers(&block)
      if Merb.test_framework == :rspec
        ExampleGroup.class_eval(&block)
      else
        raise NotImplementedError
      end
    end

    module Matchers
    end

    class ::RSpec::Core::ExampleGroup
      include ::Merb::Test::Matchers
      include ::Merb::Test::RouteHelper
      include ::Merb::Test::ControllerHelper

      if defined?(::Webrat)
        include ::Webrat::Methods
      end
    end
  end
end

module Spec
  module Matchers

    def self.create(*names, &block)
      @guid ||= 0
      Merb::Test::Matchers.module_eval do
        klass = Class.new(MatcherDSL) do
          def initialize(expected_value)
            @expected_value = expected_value
          end
        end
        klass.class_eval(&block)

        names.each do |name|
          define_method(name) do |*expected_value|
            # Avoid a warning for the form should foo.
            klass.new(expected_value && expected_value[0])
          end
        end
      end
    end

    class MatcherDSL
      include Merb::Test::RouteHelper

      def self.matches(&block)
        define_method(:matches_proxy, &block)

        define_method(:matches?) do |object|
          @object = object
          if block.arity == 2
            matches_proxy(@object, @expected_value)
          else
            matches_proxy(@object)
          end
        end
      end

      def self.expected_value(&block)
        define_method(:transform_expected, &block)

        define_method(:initialize) do |expected_value|
          @expected_value = transform_expected(expected_value) || expected_value
        end
      end

      def self.negative_failure_message(&block)
        define_method(:proxy_negative_failure_message, &block)

        define_method(:negative_failure_message) do
          proxy_negative_failure_message(@object, @expected_value)
        end
      end

      def self.failure_message(&block)
        define_method(:proxy_failure_message, &block)

        define_method(:failure_message) do
          proxy_failure_message(@object, @expected_value)
        end
      end

      def self.message(&block)
        class_eval do
          def failure_message
            generic_message(@object, @expected_value, nil)
          end

          def negative_failure_message
            generic_message(@object, @expected_value, " not")
          end
        end

        define_method(:proxy_generic_message, &block)

        ar = block.arity

        define_method(:generic_message) do |object, expected, not_string|
          if ar == 3
            proxy_generic_message(not_string, object, expected)
          else
            proxy_generic_message(not_string, object)
          end
        end
      end
    end

  end
end
