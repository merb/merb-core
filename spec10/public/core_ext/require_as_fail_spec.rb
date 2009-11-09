require File.join(File.dirname(__FILE__), "spec_helper")

describe "using dependency to require a bad gem" do
  before(:all) do
    Gem.use_paths(File.dirname(__FILE__) / "fixtures" / "gems")
  end
  
  it "raises an error because it can't find the file" do
    lambda { dependency "bad_require_gem" }.should raise_error(LoadError)
  end
end
