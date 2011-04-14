require File.expand_path(File.join(File.dirname(__FILE__), "spec_helper"))

describe Merb::Test::Cookie do

  describe "#valid?" do
    before(:all) do
      @cookie = Merb::Test::Cookie.new("path=/", ".example.org")
    end

    it "should return true for base domain" do
      %w[example.org example.org/ example.org/some/path].each do |url|
        @cookie.valid?(URI("http://#{url}")).should be_true
      end
    end

    it "should return true for subdomains" do
      %w[foo.example.org foo.example.org/ foo.example.org/some/path].each do |url|
        @cookie.valid?(URI("http://#{url}")).should be_true
      end
    end
  end

end
