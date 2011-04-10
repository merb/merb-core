# encoding: UTF-8

module Merb
  module Test
    module ControllerHelper
      include RequestHelper
      include MultipartRequestHelper
    end
  end
end
