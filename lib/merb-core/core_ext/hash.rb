# encoding: UTF-8

require 'active_support/core_ext/hash'

# Extend by some methods not provided by ActiveSupport.
#
# Most notably, this adds a `method_missing` handler which allows to
# transform keys arbitrarily by using the {Hash#transform} and
# {Hash#transform!} methods.
class Hash

  # Explicitly enable soft error handling for some transformation
  # methods. For example, if `'constantize'` is set to `false`, then
  # `#constantize_keys` will skip keys that do not reference an
  # existing constant, and they will be missing from the resulting
  # hash.
  TRANSFORM_HARD_ERRORS = Hash.new(true).merge({
    'constantize' => false
  })

  # @return [String] The hash as attributes for an XML tag.
  #
  # @example
  #   { :one => 1, "two"=>"TWO" }.to_xml_attributes
  #     #=> 'one="1" two="TWO"'
  def to_xml_attributes
    map do |k,v|
      %{#{k.to_s.underscore.sub(/^(.{1,1})/) { |m| m.downcase }}="#{v}"}
    end.join(' ')
  end

  alias_method :to_html_attributes, :to_xml_attributes

  # Transform all keys.
  #
  # @param [Boolean] hard_failure When set to false, a transformation failure
  #   just drops the key from the returned hash. Otherwise, the whole
  #   conversion fails with potentially undefined results.
  # @return A new Hash instance with all keys transformed.
  # @yield [key, value] The return value is used as the transformed key. When
  #   the block throws `:next`, the key will be omitted from the result.
  #   By the time the block is called, the key has already been deleted
  #   from the receiver!
  #
  # @example
  #   {'foo' => 'bar'}.transform {|key| key.upcase }  #=> {'FOO' => 'bar'}
  def transform(hard_failure = true, &block)
    dup.transform!(hard_failure, &block)
  end

  # Transform all keys in-place.
  #
  # See {#transform}
  def transform!(hard_failure = true, &block)
    keys.each do |key|
      begin
        catch(:next) do
          nk, nv = yield(key, delete(key))
          self[nk] = nv
        end
      rescue
        hard_failure ? raise : nil
      end
    end

    self
  end

  # Converts all keys into string values. This is used during reloading to
  # prevent problems when classes are no longer declared.
  #
  # @return [Array] An array of they hash's keys
  #
  # @example
  #   hash = { One => 1, Two => 2 }.proctect_keys!
  #   hash # => { "One" => 1, "Two" => 2 }
  #
  # @deprecated Use ActiveSupport's #stringify_keys!
  def protect_keys!
    stringify_keys!
  end

  # Destructively and non-recursively convert each key to an uppercase string,
  # deleting nil values along the way.
  #
  # @return [Hash] The newly environmentized hash.
  #
  # @example
  #   { :name => "Bob", :contact => { :email => "bob@bob.com" } }.environmentize_keys!
  #     #=> { "NAME" => "Bob", "CONTACT" => { :email => "bob@bob.com" } }
  def environmentize_keys!
    transform! do |key, value|
      throw :next if value.nil?
      [key.to_s.upcase, value]
    end
  end

  alias :merb_hash_method_missing :method_missing

  # Implement arbitrary key transformations.
  #
  # When calling a method that is only implemented destructively, i.e.,
  # as `somethingize_keys!`, without the exclamation mark, the call
  # will return the result of the destructive transformation of a shallow
  # copy of the receiver.
  #
  # @example Convert all keys by using their `#upcase` method
  #   h1 = {'foo' => 'bar', 'bAz' => 'qux'}
  #   h1.upcase_keys  #=> {'FOO' => 'bar', 'BAZ' => 'qux}
  def method_missing(sym, *args)
    if sym.to_s =~ /(.*)_keys(!?)$/
      if $2.empty? && respond_to?("#{sym}!")
        dup.send("#{sym}!", *args)
      else
        args = [TRANSFORM_HARD_ERRORS[$1]] if args.empty?
        self.send("transform#{$2}", *args) {|key, value| [key.send($1), value] }
      end
    else
      merb_hash_method_missing(sym, *args)
    end
  end
end
