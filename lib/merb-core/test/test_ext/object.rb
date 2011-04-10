# encoding: UTF-8

class Object
  # @param [#to_s] attr The name of the instance variable to get.
  #
  # @return [Object] The instance variable @attr for this object.
  #
  # @example
  #   # In a spec
  #   @my_obj.assigns(:my_value).should == @my_value
  def assigns(attr)
    self.instance_variable_get("@#{attr}")
  end
end
