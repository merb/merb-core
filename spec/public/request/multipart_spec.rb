# encoding: utf-8

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "spec_helper"))

require 'base64'

startup_merb

module Merb::MultipartRequestSpecHelper
  def fake_file(read = nil, filename = 'sample.txt', path = filename)
    read ||= 'This is a text file with some small content in it.'
    Struct.new(:read, :filename, :path).new(read, filename, path)
  end

  def fake_multipart_request(file)
    m = Merb::Test::MultipartRequestHelper::Post.new(:file => file)
    body, head = m.to_multipart
    fake_request({:request_method => "POST", :content_type => head, :content_length => body.length}, :req => body)
  end
end

describe Merb::Request do
  include Merb::MultipartRequestSpecHelper

  it "should handle file upload for multipart/form-data posts" do
    file = fake_file
    request = fake_multipart_request(file)

    request.params[:file].should_not be_nil
    request.params[:file][:tempfile].class.should == Tempfile
    request.params[:file][:content_type].should == 'text/plain'
    request.params[:file][:size].should == file.read.length
  end

  it "should correctly format multipart posts which contain multiple parameters" do
    params = {:model => {:description1 => 'foo', :description2 => 'bar', :file => fake_file}}
    m = Merb::Test::MultipartRequestHelper::Post.new params
    body, head = m.to_multipart
    body.split('----------0xKhTmLbOuNdArY').size.should eql(5)
  end

  describe "character set handling" do
    it "should be tested in a sane environment" do
      "\xC3\xBE".should == "þ"
    end

    it "should support quoted-printable encoding for parameters" do
      # straight from RFC 2047, Section 2
      file = fake_file(nil, "=?iso-8859-1?q?this=20is=20some=20text?=")
      request = fake_multipart_request(file)

      request.params[:file][:filename].should == "this is some text"
    end

    it "should support base64 encoding for parameters" do
      file = fake_file(nil, "=?iso-8859-1?b?#{Base64.encode64('this is some text').strip}?=")
      request = fake_multipart_request(file)

      request.params[:file][:filename].should == "this is some text"
    end

    it "should receive UTF-8 data from other encodings" do
      # File name is Symbol "Thorn"
      file = fake_file(nil, "=?iso-8859-1?q?=FE?=")
      request = fake_multipart_request(file)

      # Thorn in UTF-8
      request.params[:file][:filename].should == "\xC3\xBE"
    end
  end

  it "should correctly format multipart posts which contain an array as parameter" do
    file = fake_file
    file2 = fake_file("This is another text file", "sample2.txt", "sample2.txt")
    params = {:model => {:description1 => 'foo',
                         :description2 => 'bar',
                         :child_attributes => [
                           { :file => file },
                           { :file => file2 }
                         ]
                        }}

    m = Merb::Test::MultipartRequestHelper::Post.new params
    body, head = m.to_multipart
    body.should match(/model\[child_attributes\]\[\]\[file\]/)
    body.split('----------0xKhTmLbOuNdArY').size.should eql(6)
    request = fake_request({:request_method => "POST", :content_type => head, :content_length => body.length}, :req => body)
    request.params[:model][:child_attributes].size.should == 2
  end

  it "should accept env['rack.input'] as IO object (instead of StringIO)" do
    file = fake_file
    m = Merb::Test::MultipartRequestHelper::Post.new :file => file
    body, head = m.to_multipart

    t = Tempfile.new("io")
    t.write(body)
    t.close

    fd = IO.sysopen(t.path)
    io = IO.for_fd(fd,"r")
    request = Merb::Test::RequestHelper::FakeRequest.new({:request_method => "POST", :content_type => 'multipart/form-data, boundary=----------0xKhTmLbOuNdArY', :content_length => body.length},io)

    running {request.params}.should_not raise_error
    request.params[:file].should_not be_nil
    request.params[:file][:tempfile].class.should == Tempfile
    request.params[:file][:content_type].should == 'text/plain'
    request.params[:file][:size].should == file.read.length
  end

  it "should handle GET with a content_type but an empty body (happens in some browsers such as safari after redirect)" do
      request = fake_request({:request_method => "GET", :content_type => 'multipart/form-data, boundary=----------0xKhTmLbOuNdArY', :content_length => 0}, :req => '')      
      running {request.params}.should_not raise_error
  end

  it "should handle multiple occurences of one parameter" do
    m = Merb::Test::MultipartRequestHelper::Post.new :file => fake_file
    m.push_params({:checkbox => 0})
    m.push_params({:checkbox => 1})
    body, head = m.to_multipart
    request = fake_request({:request_method => "POST",
                            :content_type => head,
                            :content_length => body.length}, :req => body)
    request.params[:file].should_not be_nil
    request.params[:checkbox].should eql '1'
  end
end
