# frozen_string_literal: true

require 'open3'
require 'strscan'

module PM
  # Expands shell references in a string in a single left-to-right pass:
  #
  #   $(command)  -- replaced with the command's stdout (trailing newline removed)
  #   $VAR, ${VAR} -- replaced with the environment variable (UPPERCASE names only; "" if unset)
  #   \$          -- a literal dollar sign; the backslash is removed
  #
  # Command output is spliced in verbatim and never re-scanned, so a `$VAR` or
  # `$(...)` that a command prints stays literal. With `erb_safe: true` any
  # `<%` in command output or an environment variable's value, or one that
  # forms where a non-empty expansion meets the text beside it, is written as
  # `<%%`, which ERB renders as a literal `<%`, so neither can open an ERB tag.
  # An expansion written inside an author's own `<% %>` tag is part of that
  # Ruby code: it is escaped the same way, which does not make it safe.
  #
  # Fenced code blocks (lines starting with ``` or ~~~) are copied through
  # untouched: a prompt can show shell syntax to the model without running it.
  #
  # Raises PM::ShellExpansionError for an unmatched `$(` and
  # PM::ShellCommandError when a command exits non-zero.
  def self.expand_shell(string, erb_safe: false)
    ShellExpander.new(string, erb_safe: erb_safe).expand
  end

  class ShellExpander
    FENCE_OPEN_REGEXP  = /[ ]{0,3}(`{3,}|~{3,})[^\n]*(?:\n|\z)/
    LINE_REGEXP        = /[^\n]*(?:\n|\z)/
    ESCAPED_DOLLAR     = /\\\$/
    COMMAND_OPEN       = /\$\(/

    def initialize(string, erb_safe: false)
      @scanner  = StringScanner.new(string)
      @erb_safe = erb_safe
      @untrusted_tail = false
    end

    def expand
      out = +''
      at_line_start = true

      until @scanner.eos?
        if at_line_start && (fence = @scanner.scan(FENCE_OPEN_REGEXP))
          append(out, fence + copy_fenced_block(fence))
        elsif @scanner.scan(ESCAPED_DOLLAR)
          append(out, '$')
        elsif @scanner.scan(COMMAND_OPEN)
          append(out, run_command, untrusted: true)
        elsif @scanner.scan(ENV_VAR_REGEXP)
          append(out, ENV.fetch(@scanner[1] || @scanner[2], ''), untrusted: true)
        else
          append(out, @scanner.getch)
        end

        at_line_start = out.end_with?("\n")
      end

      out
    end

    private

    # Returns text as it must be appended for erb_safe output. Untrusted text
    # (command output, env var values) has `<%` written as `<%%`; where a `<`
    # and a `%` meet across a boundary with untrusted text on either side, the
    # `%` is doubled. ERB renders both as a literal `<%`.
    def erb_escape(text, untrusted:, after_untrusted:, after_lt:)
      return text unless untrusted || after_untrusted

      text = text.gsub('<%', '<%%') if untrusted
      after_lt && text.start_with?('%') ? "%#{text}" : text
    end

    def append(out, text, untrusted: false)
      return out if text.empty?

      if @erb_safe && (untrusted || @untrusted_tail)
        text = erb_escape(text, untrusted:, after_untrusted: @untrusted_tail, after_lt: out.end_with?('<'))
      end
      @untrusted_tail = untrusted
      out << text
    end

    # Copies lines verbatim up to and including the closing fence (or end of input).
    def copy_fenced_block(open_line)
      marker = open_line[/`{3,}|~{3,}/]
      close  = /\A[ ]{0,3}#{Regexp.escape(marker[0])}{#{marker.length},}[ \t]*(?:\n|\z)\z/
      out    = +''

      until @scanner.eos?
        line = @scanner.scan(LINE_REGEXP)
        out << line
        break if line.match?(close)
      end

      out
    end

    # Called with the scanner positioned just after "$(". Finds the matching
    # ")" (honouring nested parentheses), runs the command, and returns its stdout.
    def run_command
      command = read_command
      output, stderr, status = Open3.capture3(command)

      raise ShellCommandError.new(command, status, stderr) unless status.success?

      $stderr.write(stderr) unless stderr.empty? # keep warnings visible, as with 1.0.x
      output.chomp
    end

    def read_command
      depth   = 1
      command = +''

      until @scanner.eos?
        char = @scanner.getch
        if char == '('
          depth += 1
        elsif char == ')'
          depth -= 1
          break if depth.zero?
        end
        command << char
      end

      raise ShellExpansionError, "Unmatched $( in shell expansion: $(#{command}" unless depth.zero?

      command
    end
  end
end
