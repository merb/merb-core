module Merb::Test::Fixtures

  module Abstract

    class Testing < Merb::AbstractController
      self._template_root = File.dirname(__FILE__) / "views"
    end

    class FilterParent < Testing
      before :print_before_filter

      def print_before_filter
        @before_string = "Before"
      end
    end

    class FilterChild1 < FilterParent
      before :print_before_filter, :only => :limited

      def index
        @before_string.to_s + " Index"
      end

      def limited
        @before_string.to_s + " Limited"
      end
    end

    class FilterChild2 < FilterParent

      def index
        @before_string.to_s + " Index"
      end

      def limited
        @before_string.to_s + " Limited"
      end
    end

    # Get inheritance straight
    class FilterChild3 < FilterParent
      def propagate
        @before_string.to_s + " test"
      end

      private

      def postfact_filter
        @before_string = "Propagate to child"
      end
    end

    class FilterChild3a < FilterChild3
      private

      def inherited_postfact_filter
        @before_string = "Propagate to parent"
      end
    end
  end # Abstract
end
