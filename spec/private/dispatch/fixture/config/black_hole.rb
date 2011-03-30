# Alternate rackup config
module Rack
  module Adapter
    class BlackHole
      def call(env)
        [ 200, { "Content-Type" => "text/plain" }, Merb::Rack::StreamWrapper.new("") ]
      end
    end
  end
end

run Rack::Adapter::BlackHole.new
