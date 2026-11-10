# frozen_string_literal: true

require_relative 'test_helper'

class PMExpandShellTest < Minitest::Test
  def test_expand_env_var_bare
    with_env('PM_TEST_VAR' => 'hello') do
      result = PM.expand_shell('Value: $PM_TEST_VAR')

      assert_equal 'Value: hello', result
    end
  end

  def test_expand_env_var_braced
    with_env('PM_TEST_VAR' => 'world') do
      result = PM.expand_shell('Value: ${PM_TEST_VAR}')

      assert_equal 'Value: world', result
    end
  end

  def test_missing_env_var_replaced_with_empty_string
    with_env('PM_NONEXISTENT_VAR' => nil) do
      result = PM.expand_shell('Value: $PM_NONEXISTENT_VAR end')

      assert_equal 'Value:  end', result
    end
  end

  def test_expand_command_substitution
    result = PM.expand_shell('Result: $(echo hello)')

    assert_equal 'Result: hello', result
  end

  def test_expand_nested_command
    result = PM.expand_shell('Result: $(echo $(echo nested))')

    assert_equal 'Result: nested', result
  end

  def test_expand_multiple_commands
    result = PM.expand_shell('A: $(echo one) B: $(echo two)')

    assert_equal 'A: one B: two', result
  end

  def test_failed_command_raises
    assert_raises(PM::ShellCommandError) do
      PM.expand_shell('$(exit 1)')
    end
  end

  def test_expand_shell_in_parse_file
    with_env('PM_TEST_USER' => 'alice', 'PM_TEST_HOME' => '/home/alice') do
      parsed = PM.parse(fixture('with_shell.md'))

      assert_includes parsed.content, 'User: alice'
      assert_includes parsed.content, 'Home: /home/alice'
      assert_includes parsed.content, 'Echo: hello'
    end
  end

  def test_does_not_expand_lowercase_vars
    result = PM.expand_shell('Value: $lowercase')

    assert_equal 'Value: $lowercase', result
  end
end

class PMShellFlagTest < Minitest::Test
  def test_shell_disabled_skips_env_expansion
    parsed = PM.parse(fixture('shell_disabled.md'))

    assert_includes parsed.content, '$USER'
  end

  def test_shell_disabled_skips_command_substitution
    parsed = PM.parse(fixture('shell_disabled.md'))

    assert_includes parsed.content, '$(echo hello)'
  end

  def test_shell_enabled_by_default
    with_env('PM_TEST_USER' => 'alice', 'PM_TEST_HOME' => '/home/alice') do
      parsed = PM.parse(fixture('with_shell.md'))

      assert_includes parsed.content, 'User: alice'
    end
  end

  def test_shell_flag_in_metadata
    parsed = PM.parse(fixture('shell_disabled.md'))

    assert_equal false, parsed.metadata.shell
    assert_equal false, parsed.metadata.shell?
  end
end
