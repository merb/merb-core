# encoding: UTF-8

module Merb::Test::MultipartRequestHelper

  def multipart_request(path, params = {}, env = {})
    multipart = Merb::Test::MultipartRequestHelper::Post.new(params)
    body, head = multipart.to_multipart
    env["CONTENT_TYPE"] = head
    env["CONTENT_LENGTH"] = body.size
    env[:input] = StringIO.new(body)
    request(path, env)
  end

  # @see ::Merb::Test::MultipartRequestHelper#multipart_post
  def multipart_post(path, params = {}, env = {})
    env[:method] = "POST"
    multipart_request(path, params, env)
  end

  # @see ::Merb::Test::MultipartRequestHelper#multipart_put
  def multipart_put(path, params = {}, env = {}, &block)
    env[:method] = "PUT"
    multipart_request(path, params, env)
  end

end
