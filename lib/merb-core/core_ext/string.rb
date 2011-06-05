require "pathname"

class String
  # Join with _o_ as a file path.
  #
  # @example
  #   "merb"/"core_ext" #=> "merb/core_ext"
  #
  # @param [String] o Path component to join with receiver.
  #
  # @return [String] Receiver joined with o as a file path.
  #
  # @note Taken from Extlib
  # @deprecated Consider using paths with literal slashes.
  # @api private
  def /(o)
    File.join(self, o.to_s)
  end

  # Shortcut to Pathname#relative_path_from
  #
  # @note Uses the "pathname" core module.
  def relative_path_from(s)
    Pathname.new(self).relative_path_from(Pathname.new(s)).to_s
  end

  # Join strings with the line separator.
  #
  # @param [#to_s] args List of string-like objects
  #
  # @return [String] A single string.
  #
  # @example
  #   $/
  #   #=> "\n"
  #   String.lines("a", "b", "c")
  #   #=> "a\nb\nc"
  def self.lines(*args)
    args.map(&:to_s).join($/)
  end
end
