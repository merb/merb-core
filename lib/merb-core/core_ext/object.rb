require 'set'
require 'active_support/core_ext/object/blank'

class Object
  # @param duck<Symbol, Class, Array> The thing to compare the object to.
  #
  # @note
  #   The behavior of the method depends on the type of duck as follows:
  #   Symbol:: Check whether the object respond_to?(duck).
  #   Class:: Check whether the object is_a?(duck).
  #   Array::
  #     Check whether the object quacks_like? at least one of the options in the
  #     array.
  #
  # @return [Boolean]
  #   True if the object quacks like duck.
  #
  # @note Taken from Extlib
  # @deprecated
  # @api private
  def quacks_like?(duck)
    case duck
    when Symbol
      self.respond_to?(duck)
    when Class
      self.is_a?(duck)
    when Array
      duck.any? {|d| self.quacks_like?(d) }
    else
      false
    end
  end
end
