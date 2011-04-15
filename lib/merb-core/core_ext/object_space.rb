module ObjectSpace

  class << self

    # @return [Array<Class>] All the classes in the object space.
    #
    # @note Taken from Extlib
    # @deprecated
    # @api private
    def classes
      klasses = []
      ObjectSpace.each_object(Class) {|o| klasses << o}
      klasses
    end
  end

end
