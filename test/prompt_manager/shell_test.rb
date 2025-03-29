require 'minitest/autorun'
require_relative '../../lib/prompt_manager/shell'

class ShellTest < Minitest::Test
  def setup
    @shell = Shell.new
  end

  def test_is_dangerous_with_dangerous_command
    result, reason = @shell.is_dangerous?('rm -rf /')
    assert_equal true, result
    assert_match /dangerous operation/, reason
  end

  def test_is_dangerous_with_wildcard
    result, reason = @shell.is_dangerous?('ls *.txt')
    assert_equal true, result
    assert_match /wildcards/, reason
  end

  def test_is_dangerous_with_shell_script
    result, reason = @shell.is_dangerous?('bash script.sh')
    assert_equal true, result
    assert_match /execute a shell script/, reason
  end

  def test_is_dangerous_with_safe_command
    result, reason = @shell.is_dangerous?('echo Hello World')
    assert_equal false, result
    assert_nil reason
  end

  def test_execute_dangerous_command_with_confirmation
    # Simulate user input for confirmation
    IO.popen('echo y', 'r+') do |pipe|
      pipe.puts 'y'
      pipe.close
      output = @shell.execute('rm -rf /')
      assert_match /WARNING/, output
    end
  end

  def test_execute_safe_command
    output = @shell.execute('echo Hello World')
    assert_equal "Hello World\n", output
  end

  def test_execute_command_fails
    output = @shell.execute('invalid_command')
    assert_match /Command execution failed/, output
  end
end
