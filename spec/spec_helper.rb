require "rspec"
require 'rack/test'

require File.join(File.dirname(__FILE__), "..", "lib", "merb-core")

module Merb
  module SpecUtilityMethods
    # Determine the filename of the calling spec. Use the topmost
    # "*_spec.rb" file.
    def self.calling_spec
      cs = caller.map {|c| parse_caller(c)}.select {|c| c[0] =~ /_spec\.rb\Z/}.last

      if cs.nil? || cs.empty?
        "(none)"
      else
        "#{File.basename(cs[0])}:#{cs[1]}"
      end
    end

    def self.parse_caller(at)
      if /^(.+?):(\d+)(?::in `(.*)')?/ =~ at
        file = Regexp.last_match[1]
        line = Regexp.last_match[2].to_i
        method = Regexp.last_match[3]
        [file, line]
      end
    end
  end
end

def startup_merb(opts = {})
  default_options = {
    :environment => 'test',
    :adapter => 'runner',
    :gemfile => File.join(File.dirname(__FILE__), "Gemfile"),
    :log_level => :error,
    :fork_for_class_load => false,
    :name => Merb::SpecUtilityMethods.calling_spec
  }
  options = default_options.merge(opts)
  Merb.start_environment(options)
end

# -- Global custom matchers --

module Merb
  module Test
    module RspecMatchers
      class IncludeLog
        def initialize(expected)
          @expected = expected
        end

        def matches?(target)
          target.rewind
          @text = target.read
          @text =~ (String === @expected ? /#{Regexp.escape @expected}/ : @expected)
        end

        def failure_message
          "expected to find `#{@expected}' in the log but got:\n" <<
          @text.split("\n").map {|s| "  #{s}" }.join
        end

        def negative_failure_message
          "exected not to find `#{@expected}' in the log but got:\n" <<
          @text.split("\n").map {|s| "  #{s}" }.join
        end

        def description
          "include #{@text} in the log"
        end
      end

      def include_log(expected)
        IncludeLog.new(expected)
      end
    end

    module Helper
      def running(&blk) blk; end

      def executing(&blk) blk; end

      def doing(&blk) blk; end

      def calling(&blk) blk; end
    end
  end
end

# Helper to extract cookies from headers
#
# This is needed in some specs for sessions and cookies
module Merb::Test::CookiesHelper
  def extract_cookies(header)
    header['Set-Cookie'] ? header['Set-Cookie'].split(Merb::Const::NEWLINE) : []
  end
end

RSpec.configure do |config|
  config.include Merb::Test::Helper
  config.include Merb::Test::RspecMatchers
  config.include ::Webrat::Matchers
  config.include ::Webrat::HaveTagMatcher
  #config.include Merb::Test::RequestHelper
  config.include Merb::Test::RouteHelper
  config.include Merb::Test::WebratHelper
  config.include Rack::Test::Methods

  def reset_dependency(name, const = nil)
    Object.send(:remove_const, const) if const && Object.const_defined?(const)
    Merb::BootLoader::Dependencies.dependencies.delete_if do |d|
      d.name == name
    end
    $LOADED_FEATURES.delete("#{name}.rb")
  end

  def with_level(level)
    Merb::Config[:log_stream] = StringIO.new
    Merb::Config[:log_level] = level
    Merb.reset_logger!
    yield
    Merb::Config[:log_stream]
  end

  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end

  alias silence capture
end
