# frozen_string_literal: true

require 'open3'

module PM
  # Expands shell references in a string.
  # $ENVAR and ${ENVAR} are replaced with the environment variable value.
  # $(command) is executed and replaced with its stdout.
  def self.expand_shell(string)
    result = expand_commands(string)
    expand_env_vars(result)
  end

  # Replaces $(command) with the command's stdout.
  # Handles nested parentheses in commands.
  def self.expand_commands(string)
    result = string.dup
    pos = 0

    while (start = result.index(COMMAND_START, pos))
      depth = 0
      i = start + 1

      while i < result.length
        if result[i] == '('
          depth += 1
        elsif result[i] == ')'
          depth -= 1
          if depth == 0
            command = result[(start + 2)...i]
            output, status = Open3.capture2(command)
            output = output.chomp
            unless status.success?
              raise "Shell command failed (exit #{status.exitstatus}): #{command}"
            end
            result[start..i] = output
            pos = start + output.length
            break
          end
        end
        i += 1
      end

      break if depth != 0
    end

    result
  end
  private_class_method :expand_commands

  # Replaces $ENVAR and ${ENVAR} with environment variable values.
  # Missing variables are replaced with an empty string.
  def self.expand_env_vars(string)
    string.gsub(ENV_VAR_REGEXP) { ENV.fetch($1 || $2, '') }
  end
  private_class_method :expand_env_vars
end
