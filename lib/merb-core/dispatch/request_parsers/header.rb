# encoding: UTF-8

require 'cgi'

module Merb::Parse

  # Encapsulate header parameters.
  class HeaderParameter
    attr_accessor :name
    attr_accessor :value
    attr_accessor :sequence
    attr_accessor :charset

    # @param [String] name Parameter name. If it contains a sequence number
    #   (e.g., `"name*1"`) and no sequence number is given, it will be
    #   stripped and the sequence number is set automatically.
    # @param [String] value Parameter value. This is *not* processed here,
    #   but expected to be UTF-8.
    # @param [Integer] sequence Continuation sequence number. When
    #   explicitly set >0, this will override a sequence number in `name`.
    #
    # @param
    def initialize(name, value, sequence=-1, charset = nil)
      if name.match(PARAMCONT_REGEX)
        @name = $1
        @sequence = sequence < 0 ? $2.to_i : sequence
      else
        @name = name
        @sequence = sequence
      end

      @value = value
      @charset = charset
    end

    def name_sort_cmp(b)
      raise ArgumentError.new("Can only compare to other parameters") unless b.is_a? self.class

      res = (@name <=> b.name)

      return res if res != 0

      @sequence <=> b.sequence
    end

    def ==(b)
      @name == b.name && @value == b.value && @sequence == b.sequence
    end

    def to_ary
      [@name, @value]
    end

    def inspect
      "#<#{self.class}: name=#{@name.inspect}, value=#{value.inspect}#{@sequence > 0 ? ", seq=#{@sequence}" : ""}#{@charset.nil? ? "" : ", charset=#{@charset}"}>"
    end

    # Decode a parameter part.
    #
    # @note See RFC 2184
    #
    # Only deals with actual decoding. Collation has to be done separately.
    # The example from RFC 2184
    #
    #     Content-Type: application/x-stuff
    #       title*1*=us-ascii'en'This%20is%20even%20more%20
    #       title*2*=%2A%2A%2Afun%2A%2A%2A%20
    #       title*3="isn't it!"
    #
    # would need to be parsed parameter by parameter, and would in the end
    # yield:
    #
    #     [
    #       ["title*1" => "This is even more "],
    #       ["title*2" => "***fun*** "],
    #       ["title*3" => "isn't it!"]
    #     ]
    #
    # This implementation discards the language hint.
    #
    # @param [String] k Parameter "key"
    # @param [String] v Parameter value. Assumed to be cleaned of surrounding
    #   double quotes. The RFC assumes this to not contain "'", '*', or raw
    #   "%" characters; we just stuff it through URL decoding, so we
    #   potentially support a superset of valid parameters.
    # @param [String] charset A character set to assume. This should be `nil`
    #   unless dealing with a continuation for which a character set has been
    #   specified.
    #
    # @return [Parameter] UTF-8 encoded parameter.
    #
    # @example
    #   decode('param', 'this is some text')
    #   #=> ["param", "this is some text"]
    #
    #   decode('param*', "us-ascii'en-us'This%20is%20%2A%2A%2Afun%2A%2A%2A")
    #   #=> ["param", "This in ***fun***"]
    #
    #   decode('param*1*', "us-ascii'en-us'This%20is%20%fun")
    #   #=> ["param*1", "This in ***fun***"]
    def self.decode(k, v, charset = nil)
      # make sure we're dealing with byte soup
      v.encode!('ASCII-8BIT') if v.respond_to? :encode!

      section = -1
      text =
        begin
          # extended value?
          if k =~ /(.+)\*\Z/
            k = $1

            # retrieve a section number
            if k =~ /.+\*(\d+)\Z/
              section = $1.to_i
            else
              section = 1
            end

            if section == 1
              # just discard the language now, not like we need it.
              new_charset, _, val = v.split("'", 3)

              # handle missing encoding info (e.g. inside continuations)
              raise ArgumentError.new("Malformed encoded parameter: k=\"#{k}*\", v=\"#{v}\"") if val.nil?

              charset = new_charset.downcase unless new_charset.nil? || new_charset.empty?
            else
              raise ArgumentError.new("Spurious \"'\" in continuation parameter: k=\"#{k}*\", v=\"#{v}\"") if v =~ /\'/

                val = v
            end

            # hide literal plus signs from URL decoding
            CGI.unescape(val.gsub(/\+/, '%2B'))
          else
            v
          end
        end

      # re-interpret text from byte soup to supposed charset to UTF-8
      if !(charset.nil? || charset.empty?) && text.respond_to?(:encode)
        text = text.encode('ASCII-8BIT')
        text = text.encode('utf-8', charset)
      end

      self.new(k, text, section, charset)
    end

    # Collate parameters
    #
    # @note See RFC 2184
    #
    # @param [Array<Parameter>] p
    #
    # @return [Array<Parameter>]
    #
    # @example
    #   HeaderParameter.collate(
    #     [ HeaderParameter.new('para*1', 'This is'),
    #       HeaderParameter.new('para*2', 'fun!'),
    #       HeaderParameter.new('parb', 'No, really!')
    #     ]).to_a
    #   #=> [['para', 'This is fun!'], ['parb', 'No, really!']]
    def self.collate(p)
      result = p.sort {|a, b|
        a.name_sort_cmp(b)
      }.inject({}) {|state, param|
        if state.has_key? param.name
          if state[param.name].sequence < param.sequence
            state[param.name].value += param.value
          end
        else
          state[param.name] = param
        end

        state
      }

      # clean up sequence information
      result.values.each {|p| p.sequence = -1}
    end

  end

  # Quick and dirty unescaping of quoted string parameters.
  #
  # @param [String] s
  #
  # @return [String] A copy of `s` with all instances of `'\X'` replaced
  #   by `'X'`
  def self.unescape_quoted_string(s)
    s.gsub(/\\(.)/, '\1')
  end

  # Decode a header field.
  #
  # @note See RFC 2047. Handles language hints as specified in RFC 2184
  #   but discards the value.
  #
  # @param [String] s
  #
  # @return [String] UTF-8 encoded header value.
  #
  # @raise [ArgumentError] when an invalid encoding is passed in. Supported
  #   encodings are 'b' (base64) and 'q' (quoted printable).
  #
  # @example
  #   decode_header_text('this is some text')
  #   #=> "this is some text"
  #
  #   decode_header_text('=?iso-8859-1?q?this=20is=20some=20text?=')
  #   #=> "this is some text"
  #
  # @todo Only works on VMs supporting String#encode
  def self.decode_header_text(s)
    ret = ""

    m = s.strip.match(ENCHEADER_REGEX)

    if m.nil?
      text = s
    else
      charset, enc, text = m[1..3]

      case enc.downcase
      when 'b'
        text = Base64.decode64(text)

      when 'q'
        text.tr!('_', "\x20")
        text = text.unpack('M*').first

      else
        raise ArgumentError.new "Invalid encoding '#{enc}'"
      end
    end

    if !(charset.nil? || charset.empty?) && text.respond_to?(:encode)
      # re-interpret text from byte soup to supposed charset to UTF-8
      # the charset parameter might contain a language specification
      # after an asterisk (RFC 2184, section 5)
      text = text.encode('ASCII-8BIT').encode('utf-8', charset.split('*').first)
    end

    text
  end

  # Parse header contents with parameters
  #
  # @param [String] s Raw header content
  # @param [String] initial_name Name for the leading header fragment.
  # @param [String] defaults Parameter defaults.
  #
  # @return [Hash]
  #
  # @example
  #   parse_parameterized_header("text/plain charset=utf-8", "type")
  #   #=> { "type" => "text/plain", "charset" => "utf-8" }
  def self.parse_parametrerized_header(s, initial_name = 'main', defaults = {})
    { initial_name => '' }.merge defaults
  end

  # Parse a Content-type header line.
  #
  # @note See RFC 2616
  #
  # @param [String] s The raw header text
  #
  # @return [Hash] A Hash containing a field `"media-type"` and fields for
  #   all valid parameters. The media-type field defaults to
  #   `application/octet-stream`.
  #
  # @example
  #   parse_content_type('text/plain; charset=UTF-8')
  #   #=> { 'media-type' => 'text/plain', 'charset' => 'UTF-8' }
  def self.parse_content_type(s)
    ret = { 'media-type' => 'application/octet-stream' }
    s.strip!

    media_type = s.slice(/\A(#{P_ATOM}\/#{P_ATOM})/n, 1)
      return ret if media_type.nil?

    ret['media-type'] = media_type.downcase

    s = $~.post_match
    while s =~ PARAM_SEP_REGEX do
      s = $~.post_match
      break if s.empty?

      m = s.match(PARAM_REGEX)
      s = $~.post_match
      break if m.nil?
      next if m[1].downcase == 'media-type'

      p = HeaderParameter.decode(m[1], m[2] || unescape_quoted_string(m[3]))
      ret[p.name.downcase] = p.value
    end

    ret
  end

end
