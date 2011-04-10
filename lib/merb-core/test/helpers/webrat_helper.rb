# encoding: UTF-8

module Merb
  module Test

    # A module to allow Webrat accessing the Merb rack application
    #
    # Webrat tries to call on the context of the test example an app
    # method which should return the Rack app Webrat will use.
    #
    # Mix this module in to have fully working Webrat specs which uses
    # the Merb application returned by the Bootloader with all the
    # middleware you have in your app.
    module WebratHelper
      def app
        Merb::Config[:app]
      end
    end
  end
end
