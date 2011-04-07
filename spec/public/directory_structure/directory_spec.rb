require File.join(File.dirname(__FILE__), "..", "..", "spec_helper")
startup_merb(:merb_root => File.join(File.dirname(__FILE__), "directory"))

describe "The default Merb directory structure" do

  it "should load in controllers" do
    calling { DirectoryBase }.should_not raise_error
  end

  it "should be able to complete the dispatch cycle" do
    controller = dispatch_to(DirectoryBase, :string)
    controller.body.should == "String"
  end

  it "should be able to complete the dispatch cycle with templates" do
    controller = dispatch_to(DirectoryBase, :template)
    controller.body.should == "Template ERB"
  end

end

describe "Modifying the _template_path" do

  it "should move the templates to a new location" do
    controller = dispatch_to(Custom, :template)
    controller.body.should == "Wonderful Template"
  end

end

describe "Merb.root" do

  it "should return a path relative to Merb.root", :public_api => true do
    path = Merb.root('/app/controllers/base.rb')
    path.to_s.should == File.join(Merb.root, '/app/controllers/base.rb')
  end

  it "should accept multiple arguments like File.join", :public_api => true do
    path = Merb.root('app', 'controllers', 'base.rb')
    path.to_s.should == File.join(Merb.root, 'app', 'controllers', 'base.rb')
  end

end
