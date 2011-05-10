# encoding: utf-8

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "spec_helper"))
startup_merb
describe Merb::Parse do
  it "should be tested in a sane environment" do
    "\xC3\xBE".should == "þ"
  end

  describe 'decode_header_text' do
    it "should be a no-op on literal text" do
      Merb::Parse.decode_header_text("This is a test").should == "This is a test"
    end

    it "should support quoted-printable encoding for parameters" do
      # straight from RFC 2047, Section 2
      res = Merb::Parse.decode_header_text("=?iso-8859-1?q?this=20is=20some=20text?=")
      res.should == "this is some text"
    end

    it "should handle '+' and '_' in quoted-printable" do
      Merb::Parse.decode_header_text("=?iso-8859-1?q?a+b_c?=").should == "a+b c"
    end

    it "should support base64 encoding for parameters" do
      res = Merb::Parse.decode_header_text("=?iso-8859-1?b?#{Base64.encode64('this is some text').strip}?=")
      res.should == "this is some text"
    end

    it "should receive UTF-8 data from other encodings" do
      # symbol "Thorn" in 8859-1
      res = Merb::Parse.decode_header_text("=?iso-8859-1?q?=FE?=")
      res.should == "\xC3\xBE"
    end

    it "should raise an error for an unknown encoding" do
      expect {
        Merb::Parse.decode_header_text("=?iso-8859-1?ZZZ?=FE?=")
      }.to raise_error(ArgumentError)
    end

    it "should raise an error for an unknown charset" do
      expect {
        Merb::Parse.decode_header_text("=?myso-qqqq-unknown?q?=FE?=")
      }.to raise_error
    end
  end

  describe Merb::Parse::HeaderParameter do
    it "should pass clean parameters" do
      res = Merb::Parse::HeaderParameter.decode('param', 'this is some text')

      res.name.should == 'param'
      res.value.should == 'this is some text'
    end

    it "should convert to UTF-8" do
      res = Merb::Parse::HeaderParameter.decode('param*', "iso-8859-1''%FE")

      res.name.should == 'param'
      res.value.should == "\xC3\xBE"
    end

    it "should work on the RFC example" do
      res = Merb::Parse::HeaderParameter.decode('param*', "us-ascii'en-us'This%20is%20%2A%2A%2Afun%2A%2A%2A")

      res.name.should == 'param'
      res.value.should == 'This is ***fun***'
    end

    it "should work on the RFC example with a continuation number" do
      res = Merb::Parse::HeaderParameter::decode('param*1*', "us-ascii'en-us'This%20is%20%2A%2A%2Afun%2A%2A%2A")

      res.name.should == 'param'
      res.sequence.should == 1
      res.value.should == 'This is ***fun***'
    end

    it "should raise an error when missing information" do
      expect {
        Merb::Parse::HeaderParameter.decode('param*1*', 'This%20is%20wrong')
      }.to raise_error(ArgumentError)
    end

    it "should raise an error when encountering unexpected encoding specification" do
      expect {
        Merb::Parse::HeaderParameter.decode('param*2*', "us-ascii''This%20is%20wrong")
      }.to raise_error(ArgumentError)
    end

  end

  describe "collate_parameters" do
    #TODO: this just sucks and should be moved to a convenience function
    it "should pass the complex RFC example" do
      ret = Merb::Parse::HeaderParameter.collate(
        [
          ["title*1*", "us-ascii'en'This%20is%20even%20more%20"],
          ["title*2*", "%2A%2A%2Afun%2A%2A%2A%20"],
          ["title*3", "isn't it!"]
        ].inject({:charset => nil, :result => []}) {|result, p|
          res = Merb::Parse::HeaderParameter.decode(p[0], p[1], result[:charset])
          result[:result] << res
          result[:charset] = res.charset

          result
        }[:result]
      )

      ret.size.should == 1
      ret.first.name.should == 'title'
      ret.first.value.should == 'This is even more ***fun*** isn\'t it!'
    end

    it "should pass the documentation example" do
      ret = Hash[
        Merb::Parse::HeaderParameter.collate(
          [
            Merb::Parse::HeaderParameter.new('para*1', 'This is '),
            Merb::Parse::HeaderParameter.new('para*2', 'fun!'),
            Merb::Parse::HeaderParameter.new('parb', 'No, really!')
          ]
        ).to_a
      ]

      ret.keys.size.should == 2
      ret['para'].should ==  'This is fun!'
      ret['parb'].should ==  'No, really!'
    end

  end

  describe "decode_content_type" do
    it "should default to application/octet-stream" do
      ct = Merb::Parse.parse_content_type('')

      ct['media-type'].should == 'application/octet-stream'
    end

    it "should parse a single media type" do
      ct = Merb::Parse.parse_content_type('text/plain')

      ct['media-type'].should == 'text/plain'
    end

    it "should parse a single parameter" do
      ct = Merb::Parse.parse_content_type('text/plain; charset=iso-8859-15')

      ct['media-type'].should == 'text/plain'
      ct['charset'].should == 'iso-8859-15'
    end

    it "should parse multiple parameters" do
      ct = Merb::Parse.parse_content_type('text/plain; charset=iso-8859-15 ;    pet=duck')

      ct['media-type'].should == 'text/plain'
      ct['charset'].should == 'iso-8859-15'
      ct['pet'].should == 'duck'
    end

    it "should downcase the media type and parameter keys" do
      ct = Merb::Parse.parse_content_type('tEXt/PLAIN; CharSet=ISO-8859-15 ;    peT=dUcK')

      ct['media-type'].should == 'text/plain'
      ct['charset'].should == 'ISO-8859-15'
      ct['pet'].should == 'dUcK'
    end

    it "should ignore spurious media-type parameters" do
      ct = Merb::Parse.parse_content_type('text/plain; media-type=fake')

      ct['media-type'].should == 'text/plain'
    end

    it "should support quoted parameter strings" do
      ct = Merb::Parse.parse_content_type('text/plain; charset="iso-8859-15"')

      ct['media-type'].should == 'text/plain'
      ct['charset'].should == 'iso-8859-15'
    end

    it "should support escaping in quoted parameter strings" do
      ct = Merb::Parse.parse_content_type('text/plain; charset="\\iso\"-8859-15\\\\"')

      ct['media-type'].should == 'text/plain'
      ct['charset'].should == 'iso"-8859-15\\'
    end

  end
end

describe Merb::Request, "#method" do
  
  [:get, :head, :put, :delete].each do |method|
    it "should use the HTTP if it was a #{method.to_s.upcase}" do
      fake_request(:request_method => method.to_s).method.should == method
    end

    it "should use the _method body params for #{method.to_s.upcase} when it came in as a POST" do
      request = fake_request({:request_method => "POST"}, :post_body => "_method=#{method}")
      request.method.should == method
    end
    
    it "should use the _method query params for #{method.to_s.upcase} when it came in as a POST" do
      Merb::Request.parse_multipart_params = false
      request = fake_request(:request_method => "POST", :query_string => "_method=#{method}")
      request.method.should == method      
    end
    
    [:get, :head, :put, :delete].each do |meth|
      it "should return #{method == meth} when calling #{meth}? and the method is :#{method}" do
        request = fake_request({:request_method => method.to_s})
        request.send("#{meth}?").should == (method == meth)
      end
    end
  end

  it "should not try to parse the request body as JSON on GET" do
    request = fake_request({:request_method => "GET", :content_type => "application/json"}, :req => "")
    lambda { request.params }.should_not raise_error(JSON::ParserError)
    request.params.should == {}
  end
  
  it "should return an empty hash when XML is not parsable" do
    request = fake_request({:content_type => "application/xml"}, :req => '')
    lambda { request.params }.should_not raise_error
    request.params.should == {}
  end
  
  it "should default to POST if the _method is not defined" do
    request = fake_request({:request_method => "POST"}, :post_body => "_method=zed")
    request.method.should == :post
  end
  
  it "should raise an error if an unknown method is used" do
    request = fake_request({:request_method => "foo"})
    running {request.method}.should raise_error
  end
    
end

describe Merb::Request, " query and body params" do
  
  before(:all) { Merb::BootLoader::Dependencies.enable_json_gem }
  
  TEST_PARAMS = {
    "foo=bar&baz=bat"                       => {"foo" => "bar", "baz" => "bat"},
    "foo=bar&foo=baz"                       => {"foo" => "baz"},
    "foo[]=bar&foo[]=baz"                   => {"foo" => ["bar", "baz"]},
    "foo[][bar]=1&foo[][bar]=2"             => {"foo" => [{"bar" => "1"},{"bar" => "2"}]},
    "foo[bar][][baz]=1&foo[bar][][baz]=2"   => {"foo" => {"bar" => [{"baz" => "1"},{"baz" => "2"}]}},
    "foo[1]=bar&foo[2]=baz"                 => {"foo" => {"1" => "bar", "2" => "baz"}},
    
    "foo[bar][baz]=1&foo[bar][zot]=2&foo[bar][zip]=3&foo[bar][buz]=4" => {"foo" => {"bar" => {"baz" => "1", "zot" => "2", "zip" => "3", "buz" => "4"}}},
    "foo[bar][][baz]=1&foo[bar][][zot]=2&foo[bar][][zip]=3&foo[bar][][buz]=4" => {"foo" => {"bar" => [{"baz" => "1", "zot" => "2", "zip" => "3", "buz" => "4"}]}},
    "foo[bar][][baz]=1&foo[bar][][zot]=2&foo[bar][][baz]=3&foo[bar][][zot]=4" => {"foo" => {"bar" => [{"baz" => "1", "zot" => "2"},{"baz" => "3", "zot" => "4"}]}},
    "foo[bar][][baz]=1&foo[bar][][zot]=2&foo[bar][][fuz]=A&foo[bar][][baz]=3&foo[bar][][zot]=4&foo[bar][][fuz]=B" => {"foo" => {"bar" => [{"baz" => "1", "zot" => "2", "fuz" => "A"},{"baz" => "3", "zot" => "4", "fuz" => "B"}]}},
    "foo[bar][][baz]=1&foo[bar][][zot]=2&foo[bar][][fuz]=A&foo[bar][][baz]=3&foo[bar][][zot]=4&foo[bar][][foz]=C" => {"foo" => {"bar" => [{"baz" => "1", "zot" => "2", "fuz" => "A"},{"baz" => "3", "zot" => "4", "foz" => "C"}]}},
    "foo[bar][][baz]=1&foo[bar][][zot]=2&foo[bar][][fuz]=A&foo[bar][][baz]=3&foo[bar][][zot]=4" => {"foo" => {"bar" => [{"baz" => "1", "zot" => "2", "fuz" => "A"},{"baz" => "3", "zot" => "4"}]}},
    "foo[bar][][baz]=1&foo[bar][][zot]=2&foo[bar][][fuz]=A&foo[bar][][baz]=3&foo[bar][][zot]=4&foo[bar][][fuz]=B&foo[bar][][foz]=C" => {"foo" => {"bar" => [{"baz" => "1", "zot" => "2", "fuz" => "A"},{"baz" => "3", "zot" => "4", "fuz" => "B", "foz" => "C"}]}},
    "foo[][bar][][baz]=1&foo[][bar][][zot]=2&foo[][bar][][fuz]=A&foo[][bar][][baz]=3&foo[][bar][][zot]=4&foo[][bar][][fuz]=B&foo[][bar][][foz]=C" => {"foo" => {"bar" => [{"baz" => "1", "zot" => "2", "fuz" => "A"},{"baz" => "3", "zot" => "4", "fuz" => "B", "foz" => "C"}]}}
  }
  
  TEST_PARAMS.each do |query, parse|

     it "should convert #{query.inspect} to #{parse.inspect} in the query string" do
       request = fake_request({:query_string => query})
       request.params.should == parse
     end

     it "should convert #{query.inspect} to #{parse.inspect} in the post body" do
       request = fake_request({}, :post_body => query)
       request.params.should == parse
     end
   
   end
   
  it "should support JSON params" do
    request = fake_request({:content_type => "application/json"}, :req => %{{"foo": "bar"}})
    request.params.should == {"foo" => "bar"}
  end
  
  it "should populated the inflated_object parameter if JSON params do not inflate to a hash" do
    request = fake_request({:content_type => "application/json"}, :req => %{["foo", "bar"]})
    request.params.should have_key(:inflated_object)
    request.params[:inflated_object].should eql(["foo", "bar"])
  end
  
  it "should support XML params" do
    request = fake_request({:content_type => "application/xml"}, :req => %{<foo bar="baz"><baz/></foo>})
    request.params.should == {"foo" => {"baz" => nil, "bar" => "baz"}}
  end  
  
end

describe Merb::Request, "#remote_ip" do
  it "should be able to get the remote IP of a request with X_FORWARDED_FOR" do
    request = fake_request({:http_x_forwarded_for => "www.example.com"})
    request.remote_ip.should == "www.example.com"
  end
  
  it "should be able to get the remote IP when some of the X_FORWARDED_FOR are local" do
    request = fake_request({:http_x_forwarded_for => "192.168.2.1,127.0.0.1,www.example.com"})
    request.remote_ip.should == "www.example.com"
    
    %w(212.183.134.130 82.132.136.215).each do |addr|
      request = fake_request({:http_x_forwarded_for => addr})
      request.remote_ip.should == addr
    end
  end
  
  it "should be able to get the remote IP when it's in REMOTE_ADDR" do
    request = fake_request({:remote_addr => "www.example.com"})
    request.remote_ip.should == "www.example.com"    
  end
  
  it "filters private IPs from X_FORWARDED_FOR" do
    request = fake_request({:http_x_forwarded_for => "10.0.0.0,10.255.255.255,169.254.1.2,172.16.0.0,172.24.0.0,172.31.255.255,192.168.0.0,192.168.255.255,www.example.com"})
    request.remote_ip.should == 'www.example.com'
  end
end

describe Merb::Request, "#cookies" do
  
  it "should take cookies in the HTTP_COOKIE environment variable" do
    request = fake_request({:http_cookie => "merb=canhascookie; version=1"})
    request.cookies.should == {"merb" => "canhascookie", "version" => "1"}
  end
  
  it "should handle badly formatted cookies" do
    request = fake_request({:http_cookie => "merb=; ; also=hats"})
    request.cookies.should == {"merb" => "", "also" => "hats"}
  end
  
end

describe Merb::Request, " misc" do
  
  it "should contain the request start" do
    request = fake_request
    request.start.should be_instance_of(Time)
  end
  
  it "should know if a request is an XHR" do
    request = fake_request({:http_x_requested_with => "XMLHttpRequest"})
    request.should be_xhr
  end
  
  it "should know if the protocol is http or https (when HTTPS is on)" do
    request = fake_request({:https => "on"})
    request.protocol.should == "https"
    request.should be_ssl
  end

  it "should know if the protocol is http or https (when HTTP_X_FORWARDED_PROTO is https)" do
    request = fake_request({:http_x_forwarded_proto => "https"})
    request.protocol.should == "https"
    request.should be_ssl
  end

  it "should know if the protocol is http or https (when it's regular HTTP)" do
    request = fake_request({})
    request.protocol.should == "http"
  end
  
  it "should get the content-length" do
    request = fake_request({:content_length => "300"})
    request.content_length.should == 300
  end
  
  it "should be able to get the path from the URI (stripping trailing /)" do
    request = fake_request({:request_uri => "foo/bar/baz/?bat"})
    request.path.should == "foo/bar/baz"
  end
  
  it "should be able to get the path from the URI (joining multiple //)" do
    request = fake_request({:request_uri => "foo/bar//baz/?bat"})
    request.path.should == "foo/bar/baz"
  end
  
  it "should get the remote port" do
    request = fake_request({:server_port => "80"})
    request.port.should == 80
  end
  
  it "should get the parts of the remote subdomain" do
    request = fake_request({:http_host => "zoo.boom.foo.com"})
    request.subdomains.should == ["zoo", "boom"]
  end
  
  it "should get the parts of the remote subdomain when there's an irregular TLD number" do
    request = fake_request({:http_host => "foo.bar.co.uk"})
    request.subdomains(2).should == ["foo"]
  end
  
  it "should get the full domain (not including subdomains and not including the port)" do
    request = fake_request({:http_host => "www.foo.com:80"})
    request.domain.should == "foo.com"
  end

  it "should get the full domain from an irregular TLD" do
    request = fake_request({:http_host => "www.foo.co.uk:80"})
    request.domain(2).should == "foo.co.uk"
  end

  it "should get the host (with X_FORWARDED_HOST)" do
    request = fake_request({:http_x_forwarded_host => "www.example.com"})
    request.host.should == "www.example.com"
  end

  it "should get the host (without X_FORWARDED_HOST)" do
    request = fake_request({:http_host => "www.example.com"})
    request.host.should == "www.example.com"
  end
    
  {:http_referer            => ["referer", "http://referer.com"],
   :request_uri             => ["uri", "http://uri.com/uri"],
   :http_user_agent         => ["user_agent", "mozilla"],
   :server_name             => ["server_name", "apache"],
   :http_accept_encoding    => ["accept_encoding", "application/json"],
   :script_name             => ["script_name", "foo"],
   :http_cache_control      => ["cache_control", "no-cache"],
   :http_accept_language    => ["accept_language", "en"],
   :server_software         => ["server_software", "apache"],
   :http_keep_alive         => ["keep_alive", "300"],
   :http_accept_charset     => ["accept_charset", "UTF-8"],
   :http_version            => ["version", "1.1"],
   :gateway_interface       => ["gateway", "CGI/1.2"],
   :http_connection         => ["connection", "keep-alive"],
   :path_info               => ["path_info", "foo/bar/baz"],
  }.each do |env, vars|
    
    it "should be able to get the #{env.to_s.upcase}" do
      request = fake_request({env => vars[1]})
      request.send(vars[0]).should == vars[1]
    end
    
  end
  
end

describe Merb::Request, "#if_none_match" do
  it 'returns value of If-None-Match request header' do
    fake_request(Merb::Const::HTTP_IF_NONE_MATCH => "dc1562a133").if_none_match.should == "dc1562a133"
  end
end

describe Merb::Request, "#if_modified_since" do
  it 'returns value of If-Modified-Since request header' do
    t = '05 Sep 2008 22:00:27 GMT'
    fake_request(Merb::Const::HTTP_IF_MODIFIED_SINCE => t).if_modified_since.should == Time.rfc2822(t)
  end
end
