# lib/prompt_manager/shell.rb
#
# NOTE: this assumes access to stdin stdout for user interaction.
#       It also presumes that the user should be protected from
#       executing potentially dangerous commands. We could just
#       assume the user knows what they're doing.
#

require 'shellwords'
require 'open3'

class Shell
  def initialize
    @dangerous_commands = [
      'rm', 'rmdir', 'dd', 'mkfs', 'format',
      'del', ':', '>', '>>', '|',
      'chmod', 'chown', 'sudo', 'su',
      'shutdown', 'reboot', 'halt',
      'mv', 'cp' # potentially dangerous if overwriting important files
    ]
  end

  def is_dangerous?(command)
    command_lower = command.downcase

    # Check for dangerous commands
    @dangerous_commands.each do |dangerous_cmd|
      # Look for the command as a standalone word
      if command_lower =~ /\b#{Regexp.escape(dangerous_cmd)}\b/
        return true, "Command contains potentially dangerous operation: '#{dangerous_cmd}'"
      end
    end

    # Check for wildcards that might affect many files
    if command.include?('*') || command.include?('?')
      return true, "Command contains wildcards which might affect multiple files"
    end

    # Check for shell script execution
    if (command.include?('.sh') && command.include?('bash')) || command.include?('eval')
      return true, "Command appears to execute a shell script"
    end

    return false, nil
  end

  def execute(command)
    is_dangerous, reason = is_dangerous?(command)

    if is_dangerous
      # SMELL: so what? It's dangerous; but, the user put it in the code.
      #        is it the responsibility of a programming language not to
      #        execute potentially dangerous commands without user confirmation.

      puts "WARNING: #{reason}"
      print "The command '#{command}' may be dangerous. Execute anyway? (y/N): "
      confirmation = gets.chomp.downcase

      unless confirmation == 'y'
        return "Command execution aborted by user."
      end
    end

    # If we get here, either the command is safe or the user confirmed execution
    begin
      stdout_str, stderr_str, status = Open3.capture3(command)
      if status.success?
        return stdout_str
      else
        return "Command execution failed: #{stderr_str}"
      end

    rescue => e
      return "Error executing command: #{e.message}"
    end
  end
end
