# frozen_string_literal: true

module PM
  # Base class for every error PM raises itself.
  #
  # Errors from the standard library pass through unchanged:
  #   Errno::ENOENT      -- PM.parse given a file path that does not exist
  #   Psych::SyntaxError -- front matter that is not valid YAML
  #   Psych::DisallowedClass / Psych::AliasesNotEnabled -- YAML using symbols or anchors
  #   SyntaxError        -- ERB that does not compile
  class Error < StandardError; end

  # Front matter was present but not a YAML mapping, or a known key
  # (`shell`, `erb`, `parameters`) had a value of the wrong type.
  class MetadataError < Error; end

  # Shell expansion could not complete (for example an unmatched `$(`).
  class ShellExpansionError < Error; end

  # A `$(command)` exited non-zero or was killed by a signal. Carries the
  # command, its Process::Status, and whatever it wrote to stderr.
  class ShellCommandError < ShellExpansionError
    attr_reader :command, :status, :stderr

    def initialize(command, status, stderr = '')
      @command = command
      @status  = status
      @stderr  = stderr.to_s
      super(build_message)
    end

    private

    def build_message
      message = "Shell command failed (#{exit_reason}): #{command}"
      detail  = stderr.strip
      detail.empty? ? message : "#{message}\n#{detail}"
    end

    # "exit N", or "signal N" when the command was killed by a signal
    # (exitstatus is nil then).
    def exit_reason
      status.signaled? ? "signal #{status.termsig}" : "exit #{status.exitstatus}"
    end
  end

  # Base for problems raised by the built-in `include` directive.
  class IncludeError < Error; end

  # A file tried to include one of its own ancestors.
  class CircularIncludeError < IncludeError; end

  # Nesting went past PM.config.max_include_depth.
  class IncludeDepthError < IncludeError; end

  # `include` was used from a string-parsed prompt that has no directory.
  class IncludeContextError < IncludeError; end

  # `insert` / `read` named a file that does not exist.
  class FileNotFoundError < Error; end

  # PM.register (or a PM::Directive subclass) tried to claim a name that is taken.
  class DirectiveAlreadyRegisteredError < Error; end

  # Parameter problems. Subclasses ArgumentError rather than PM::Error so that
  # `rescue ArgumentError` written against 1.0.x keeps working. Rescue
  # PM::ParameterError when you want only these.
  class ParameterError < ArgumentError; end

  # A parameter declared with a `null` default was not supplied to `to_s`.
  # #names lists the missing parameter names (Strings). The message always
  # starts with "Missing required parameters:".
  class MissingParameterError < ParameterError
    attr_reader :names

    def initialize(names = [])
      @names = Array(names).map(&:to_s).freeze
      super("Missing required parameters: #{@names.join(', ')}")
    end
  end

  # Strict mode only: a template referenced a name that is neither a
  # parameter nor a registered directive.
  class UnknownParameterError < ParameterError; end
end
