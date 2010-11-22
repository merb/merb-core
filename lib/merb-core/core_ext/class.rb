class Class
  # Allows the definition of methods on a class that will be available via
  # super.
  #
  # @example
  #     class Foo
  #       chainable do
  #         def hello
  #           "hello"
  #         end
  #       end
  #     end
  #
  #     class Foo
  #       def hello
  #         super + " Merb!"
  #       end
  #     end
  #
  #     Foo.new.hello #=> "hello Merb!"
  #
  # @param &blk A block containing method definitions that should be
  #   marked as chainable
  #
  # @return [Module] The anonymous module that was created.
  def chainable(&blk)
    mod = Module.new(&blk)
    include mod
    mod
  end

  # Defines class-level and instance-level attribute reader.
  #
  # @param [*syms<Array] Array of attributes to define reader for.
  # @return [Array<#to_s>] List of attributes that were made into cattr_readers
  #
  # @api public
  #
  # @todo Is this inconsistent in that it does not allow you to prevent
  #   an instance_reader via :instance_reader => false
  def cattr_reader(*syms)
    syms.flatten.each do |sym|
      next if sym.is_a?(Hash)
      class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}
          @@#{sym}
        end

        def #{sym}
          @@#{sym}
        end
      RUBY
    end
  end

  # Defines class-level (and optionally instance-level) attribute writer.
  #
  # @param [Array<*#to_s, Hash{:instance_writer => Boolean}>] Array of attributes to define writer for.
  # @option syms :instance_writer<Boolean> if true, instance-level attribute writer is defined.
  # @return [Array<#to_s>] List of attributes that were made into cattr_writers
  #
  # @api public
  def cattr_writer(*syms)
    options = syms.last.is_a?(Hash) ? syms.pop : {}
    syms.flatten.each do |sym|
      class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}=(obj)
          @@#{sym} = obj
        end
      RUBY

      unless options[:instance_writer] == false
        class_eval(<<-RUBY, __FILE__, __LINE__ + 1)
          def #{sym}=(obj)
            @@#{sym} = obj
          end
        RUBY
      end
    end
  end

  # Defines class-level (and optionally instance-level) attribute accessor.
  #
  # @param *syms<Array[*#to_s, Hash{:instance_writer => Boolean}]> Array of attributes to define accessor for.
  # @option syms :instance_writer<Boolean> if true, instance-level attribute writer is defined.
  # @return [Array<#to_s>] List of attributes that were made into accessors
  #
  # @api public
  def cattr_accessor(*syms)
    cattr_reader(*syms)
    cattr_writer(*syms)
  end
end
