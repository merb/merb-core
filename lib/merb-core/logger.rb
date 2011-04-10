# encoding: UTF-8

# Merb::Logger = Extlib::Logger

class Merb::Logger < Extlib::Logger
  # @api public
  def verbose!(message, level = :warn)
    send("#{level}!", message) if Merb::Config[:verbose]
  end

  # @api public
  def verbose(message, level = :warn)
    send(level, message) if Merb::Config[:verbose]
  end
end

# require "time" # httpdate
module Merb

  # #### Public Merb Logger API
  #
  # To replace an existing logger with a new one:
  #     Merb.logger.set_log(log{String, IO},level{Symbol, String})
  # for example:
  #     Merb.logger.set_log($stdout, Merb::Logger::Levels[:fatal])
  #
  # Available logging levels are
  #     Merb::Logger::{ Fatal, Error, Warn, Info, Debug }
  #
  # Logging via:
  #     Merb.logger.fatal(message<String>,&block)
  #     Merb.logger.error(message<String>,&block)
  #     Merb.logger.warn(message<String>,&block)
  #     Merb.logger.info(message<String>,&block)
  #     Merb.logger.debug(message<String>,&block)
  #
  # Logging with autoflush:
  #     Merb.logger.fatal!(message<String>,&block)
  #     Merb.logger.error!(message<String>,&block)
  #     Merb.logger.warn!(message<String>,&block)
  #     Merb.logger.info!(message<String>,&block)
  #     Merb.logger.debug!(message<String>,&block)
  #
  # Flush the buffer to
  #     Merb.logger.flush
  #
  # Remove the current log object
  #     Merb.logger.close
  #
  # #### Private Merb Logger API
  #
  # To initialize the logger you create a new object, proxies to {set_log}.
  #     Merb::Logger.new(log{String, IO},level{Symbol, String})
  #
  # #### Ruby (standard) logger levels:
  #     :fatal  # An unhandleable error that results in a program crash
  #     :error  # A handleable error condition
  #     :warn   # A warning
  #     :info   # generic (useful) information about system operation
  #     :debug  # low-level information for developers
  #
  # Each key in the Levels mash is used to generate the following methods:
  #
  # * **`#key(message = nil):`** Normal logging to log-level `key`.
  # * **`#key!(message = nil):`** Logging to level `key` with auto-flush.
  # * **`#key?:`** Returns a boolean, true if logging for level `key`
  #   is enabled.
  #
  # The generated logging methods both return `self` to enable chaining.
  class Logger

    attr_accessor :level
    attr_accessor :delimiter
    attr_accessor :auto_flush
    attr_reader   :buffer
    attr_reader   :log
    attr_reader   :init_args

    # Levels for which logging methods are defined.
    Levels = Mash.new({
      :fatal => 7,
      :error => 6,
      :warn  => 4,
      :info  => 3,
      :debug => 0
    }) unless const_defined?(:Levels)

    @@mutex = {}

    public

    # To initialize the logger you create a new object, proxies to {#set_log}.
    #
    # @param *args Arguments to create the log from. See {#set_log} for specifics.
    # @see Merb::Logger#set_log
    def initialize(*args)
      set_log(*args)
    end

    # Replaces an existing logger with a new one.
    #
    # @param [IO, String] stream Either an IO object or a name of a logfile.
    # @param [#to_sym] log_level
    #   The log level from, e.g. `:fatal` or `:info`. Defaults to `:error` in the
    #   production environment and `:debug` otherwise.
    # @param [String] delimiter
    #   Delimiter to use between message sections.
    # @param [Boolean] auto_flush
    #   Whether the log should automatically flush after new messages are
    #   added.
    def set_log(stream = Merb::Config[:log_stream],
      log_level = Merb::Config[:log_level],
      delimiter = Merb::Config[:log_delimiter],
      auto_flush = Merb::Config[:log_auto_flush])

      @buffer                   = []
      @delimiter                = delimiter
      @auto_flush               = auto_flush

      if Levels[log_level]
        @level                  = Levels[log_level]
      else
        @level                  = log_level
      end

      @log                      = stream
      @log.sync                 = true
      @mutex = (@@mutex[@log] ||= Mutex.new)
    end

    # Flush the entire buffer to the log object.
    def flush
      return unless @buffer.size > 0
      @mutex.synchronize do
        @log.write(@buffer.slice!(0..-1).join(''))
      end
    end

    # Close and remove the current log object.
    def close
      flush
      @log.close if @log.respond_to?(:close) && !@log.tty?
      @log = nil
    end

    # Appends a message to the log. The methods yield to an optional block and
    # the output of this block will be appended to the message.
    #
    # @param [String] string The message to be logged.
    #
    # @return [String] The resulting message added to the log file.
    def <<(string = nil)
      message = ""
      message << delimiter
      message << string if string
      message << "\n" unless message[-1] == ?\n
      @buffer << message
      flush if @auto_flush

      message
    end
    alias :push :<<

    # Generate the logging methods for Merb.logger for each log level.
    Levels.each_pair do |name, number|
      class_eval <<-LEVELMETHODS, __FILE__, __LINE__

      # Appends a message to the log if the log level is at least as high as
      # the log level of the logger.
      #
      # Parameters
      # @param [String] string The message to be logged.
      #
      # @return self The logger object for chaining.
      def #{name}(message = nil)
        if #{number} >= level
          message = block_given? ? yield : message
          self << message if #{number} >= level
        end
        self
      end

      # Appends a message to the log if the log level is at least as high as
      # the log level of the logger. The `bang!` version of the method also auto
      # flushes the log buffer to disk.
      #
      # @param [String] string The message to be logged.
      #
      # @return self The logger object for chaining.
      def #{name}!(message = nil)
        if #{number} >= level
          message = block_given? ? yield : message
          self << message if #{number} >= level
          flush if #{number} >= level
        end
        self
      end

      # @return [Boolean] `true` if this level will be logged by this logger.
      def #{name}?
        #{number} >= level
      end
      LEVELMETHODS
    end

  end

end
