require File.join(File.dirname(__FILE__), 'spec_helper')

module Merb
  module Test
    module HashSpecHelper
      class Foo; end
      class Bar; end
    end
  end
end

describe Hash do
  it "should allow arbitrary key transformations" do
      h1 = {'foo' => 'bar', 'bAz' => 'qux'}
      h2 = h1.upcase_keys

      h2.keys.sort.should be_eql(['BAZ', 'FOO'])
  end

  it "should re-route non-destructive calls" do
    h1 = {'foo' => 'bar', 'bAz' => 'qux'}
    h2 = h1.environmentize_keys

    h1.keys.sort.should be_eql(['bAz', 'foo'])
    h2.keys.sort.should be_eql(['BAZ', 'FOO'])
  end

  describe "#transform" do
    it "Should have a non-destructive version" do
      h1 = {'foo' => 'bar', 'bAz' => 'qux'}
      h2 = h1.transform {|key, value| [key.upcase, value]}

      h1.keys.sort.should be_eql(['bAz', 'foo'])
      h2.keys.sort.should be_eql(['BAZ', 'FOO'])
    end

    it "Should have a destructive version" do
      h1 = {'foo' => 'bar', 'bAz' => 'qux'}
      h2 = h1.transform! {|key, value| [key.upcase, value]}

      h1.keys.sort.should be_eql(['BAZ', 'FOO'])
      h2.object_id.should == h1.object_id
    end

    it "Should allow to skip keys" do
      h1 = (1..10).inject(Hash.new) {|acc, n| acc[n] = 'foo'; acc}
      h2 = h1.transform do |key, value|
        throw :next if key % 2 > 0
        [key, value]
      end

      h2.keys.sort.should == [2, 4, 6, 8, 10]
    end
  end

  describe "key protection" do
    it "should protect keys" do
      h1 = {
        Merb::Test::HashSpecHelper::Foo => 'foo',
        Merb::Test::HashSpecHelper::Bar => 'bar'
      }

      h1.protect_keys!

      h1['Merb::Test::HashSpecHelper::Foo'].should == 'foo'
      h1['Merb::Test::HashSpecHelper::Bar'].should == 'bar'
    end

    it "should unprotect keys and ignore non-existing modules" do
      h1 = {
        'Merb::Test::HashSpecHelper::Foo' => 'foo',
        'Merb::Test::HashSpecHelper::DoesNotExist' => 'gone',
        'Merb::Test::HashSpecHelper::Bar' => 'bar'
      }

      h1.constantize_keys!

      h1.keys.size.should == 2
      h1[Merb::Test::HashSpecHelper::Foo].should == 'foo'
      h1[Merb::Test::HashSpecHelper::Bar].should == 'bar'
    end
  end
end
