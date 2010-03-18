# Provides conditional get support in Merb core.
# Conditional get support is intentionally
# simple and does not do fancy stuff like making
# ETag value from Ruby objects for you.
#
# The most interesting method for end user is
# +request_fresh?+ that is used after setting of
# last modification time or ETag:
#
# 
# @example
#   def show
#     self.etag = Digest::SHA1.hexdigest(calculate_cache_key(params))
#
#     if request_fresh?
#       self.status = 304
#       return ''
#     else
#       @product = Product.get(params[:id])
#       display @product
#     end
#   end
module Merb::ConditionalGetMixin

  # Sets ETag response header by calling #to_s on the argument
  #
  # @param tag [#to_s] value of ETag header
  #
  # @return [String] value of ETag header enclosed in double quotes as required by the RFC
  #
  # @api public
  def etag=(tag)
    headers[Merb::Const::ETAG] = %("#{tag}")
  end

  # Value of the ETag header
  #
  # @return [String] Value of ETag response header if set.
  # @return [nil] If ETag header not set.
  #
  # @api public
  def etag
    headers[Merb::Const::ETAG]
  end

  # Test to see if the request's Etag matches the one supplied locally
  #
  # @return [true] if ETag response header equals If-None-Match request header
  # @return [true] if it does not.
  #
  # @api public
  def etag_matches?(tag = self.etag)
    tag == self.request.if_none_match
  end

  # Sets Last-Modified response header
  #
  # @param time [Time,DateTime] The last modified time of the resource
  #
  # @return [String] The last modified time of the resource in the format required by the RFC
  #
  # @api public
  def last_modified=(time)
    time = time.to_time if time.is_a?(DateTime)
    # time.utc.strftime("%a, %d %b %Y %X") if we could rely on locale being American
    headers[Merb::Const::LAST_MODIFIED] = time.httpdate
  end

  # Value of the Last-Modified header
  #
  # @return [Time] Value of Last-Modified response header if set.
  # @return [nil] If Last-Modified not set.
  #
  # @api public
  def last_modified
    last_mod = headers[Merb::Const::LAST_MODIFIED]
    Time.rfc2822(last_mod) if last_mod
  end

  # Test to see if the request's If-Modified-Since is satisfied
  #
  # @param time [Time] Time to test if the If-Modified-Since header against
  #
  # @return [true] Last-Modified response header is < than If-Modified-Since request header
  # @return [false] otherwise
  #
  # @api public
  def not_modified?(time = self.last_modified)
    if !request.if_modified_since.nil? and !time.nil?
      time <= request.if_modified_since
    else
      false
    end
  end

  # Tests freshness of response using all supplied validators
  #
  # A response with no validators is always stale.
  #
  # @return [true] ETag matches and entity is not modified
  # @return [false] One or more validators failed, or none were supplied
  #
  # @api public
  def request_fresh?
    # make sure we have something to compare too.
    return false unless last_modified or etag

    fresh = true

    # only check if we have set the right headers
    fresh &&= etag_matches?(self.etag) if etag
    fresh &&= not_modified?(self.last_modified) if last_modified
    fresh
  end
end
