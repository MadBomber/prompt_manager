# frozen_string_literal: true

require_relative 'test_helper'

class PMShellSafetyTest < Minitest::Test
  # --- escaping ---

  def test_escaped_dollar_is_literal
    assert_equal 'cost $HOME', PM.expand_shell('cost \$HOME')
  end

  def test_escaped_dollar_stops_command_substitution
    assert_equal '$(not run)', PM.expand_shell('\$(not run)')
  end

  def test_lowercase_and_numeric_dollars_are_untouched
    assert_equal '$foo $5 $', PM.expand_shell('$foo $5 $')
  end

  # --- command output is inert ---

  def test_command_output_is_not_re_expanded_for_env_vars
    assert_equal '$HOME', PM.expand_shell(%q{$(printf '$HOME')})
  end

  def test_command_output_is_not_rescanned_for_commands
    assert_equal '$(echo nested)', PM.expand_shell(%q{$(printf '$(echo nested)')})
  end

  def test_erb_in_command_output_is_escaped_when_erb_safe
    assert_equal '<%%= 1 %>', PM.expand_shell(%q{$(printf '<%%= 1 %%>')}, erb_safe: true)
  end

  def test_erb_in_command_output_is_kept_when_not_erb_safe
    assert_equal '<%= 1 %>', PM.expand_shell(%q{$(printf '<%%= 1 %%>')})
  end

  def test_parse_string_neutralises_erb_from_command_output
    assert_equal '<%= 6*7 %>', PM.parse_string(%q{$(printf '<%%= 6*7 %%>')}).to_s
  end

  # --- environment variable values are inert ---

  def test_erb_in_env_var_value_is_escaped_when_erb_safe
    ENV['PM_TEST_ERB'] = '<%= 1 %>'

    assert_equal '<%%= 1 %> <%%= 1 %>', PM.expand_shell('$PM_TEST_ERB ${PM_TEST_ERB}', erb_safe: true)
  ensure
    ENV.delete('PM_TEST_ERB')
  end

  def test_erb_in_env_var_value_is_kept_when_not_erb_safe
    ENV['PM_TEST_ERB'] = '<%= 1 %>'

    assert_equal '<%= 1 %>', PM.expand_shell('$PM_TEST_ERB')
  ensure
    ENV.delete('PM_TEST_ERB')
  end

  def test_parse_string_neutralises_erb_from_env_var_value
    ENV['PM_TEST_ERB'] = '<%= 6*7 %>'

    assert_equal '<%= 6*7 %>', PM.parse_string('$PM_TEST_ERB').to_s
  ensure
    ENV.delete('PM_TEST_ERB')
  end

  def test_erb_tag_split_across_adjacent_env_vars_stays_literal
    ENV['PM_TEST_LT']  = '<'
    ENV['PM_TEST_ERB'] = '%= 6*7 %>'

    assert_equal '<%= 6*7 %>', PM.parse_string('$PM_TEST_LT$PM_TEST_ERB').to_s
  ensure
    ENV.delete('PM_TEST_LT')
    ENV.delete('PM_TEST_ERB')
  end

  def test_erb_tag_split_between_env_var_and_command_output_stays_literal
    ENV['PM_TEST_LT'] = '<'

    assert_equal '<%= 6*7 %>', PM.parse_string(%q{$PM_TEST_LT$(printf '%%= 6*7 %%>')}).to_s
  ensure
    ENV.delete('PM_TEST_LT')
  end

  def test_literal_lt_before_env_var_value_starting_with_percent_stays_literal
    ENV['PM_TEST_ERB'] = '%= 6*7 %>'

    assert_equal '<%= 6*7 %>', PM.parse_string('<$PM_TEST_ERB').to_s
  ensure
    ENV.delete('PM_TEST_ERB')
  end

  def test_env_var_value_ending_in_lt_before_literal_percent_stays_literal
    ENV['PM_TEST_LT'] = '<'

    assert_equal '<%= 6*7 %>', PM.parse_string('$PM_TEST_LT%= 6*7 %>').to_s
  ensure
    ENV.delete('PM_TEST_LT')
  end

  def test_literal_lt_before_command_output_starting_with_percent_stays_literal
    assert_equal '<%= 6*7 %>', PM.parse_string(%q{<$(printf '%%= 6*7 %%>')}).to_s
  end

  def test_command_output_ending_in_lt_before_literal_percent_stays_literal
    assert_equal '<%= 6*7 %>', PM.parse_string(%q{$(printf '<')%= 6*7 %>}).to_s
  end

  # --- erb_escape, in isolation ---

  def erb_escape(text, untrusted: false, after_untrusted: false, after_lt: false)
    PM::ShellExpander.new('').send(:erb_escape, text, untrusted:, after_untrusted:, after_lt:)
  end

  def test_erb_escape_leaves_trusted_text_after_trusted_text_alone
    assert_equal '%= x', erb_escape('%= x', after_lt: true)
  end

  def test_erb_escape_doubles_lt_percent_inside_untrusted_text
    assert_equal 'a<%%b', erb_escape('a<%b', untrusted: true)
  end

  def test_erb_escape_doubles_leading_percent_after_lt
    assert_equal '%%=', erb_escape('%=', untrusted: true, after_lt: true)
    assert_equal '%%', erb_escape('%', after_untrusted: true, after_lt: true)
  end

  def test_erb_escape_keeps_leading_percent_without_lt
    assert_equal '%=', erb_escape('%=', untrusted: true)
  end

  def test_empty_env_var_does_not_change_author_erb
    ENV.delete('PM_TEST_EMPTY')

    assert_equal '42', PM.parse_string('<$PM_TEST_EMPTY%= 6*7 %>').to_s
  end

  def test_erb_not_escaped_when_erb_is_disabled
    parsed = PM.parse_string("---\nerb: false\n---\n$(printf '<%%= 1 %%>')")

    assert_equal '<%= 1 %>', parsed.content
  end

  # --- fenced code blocks ---

  def test_fenced_code_block_is_not_expanded
    source = "```sh\n$(echo RAN)\n$HOME\n```\n"

    assert_equal source, PM.expand_shell(source)
  end

  def test_tilde_fence_is_not_expanded
    source = "~~~\n$(echo RAN)\n~~~\n"

    assert_equal source, PM.expand_shell(source)
  end

  def test_text_after_fence_is_expanded
    assert_equal "```\n$(echo A)\n```\nB\n", PM.expand_shell("```\n$(echo A)\n```\n$(echo B)\n")
  end

  def test_text_before_fence_is_expanded
    assert_equal "A\n```\n$(echo B)\n```", PM.expand_shell("$(echo A)\n```\n$(echo B)\n```")
  end

  def test_shorter_inner_fence_does_not_close_a_longer_one
    source = "````\n```\n$(echo X)\n````\n"

    assert_equal source, PM.expand_shell(source)
  end

  def test_unclosed_fence_runs_to_end_of_input
    source = "```\n$(echo X)\n"

    assert_equal source, PM.expand_shell(source)
  end

  def test_fence_indented_up_to_three_spaces
    source = "   ```\n$(echo X)\n   ```\n"

    assert_equal source, PM.expand_shell(source)
  end

  def test_fence_marker_mid_line_is_not_a_fence
    assert_equal 'text ``` RAN', PM.expand_shell('text ``` $(echo RAN)')
  end

  def test_parse_string_skips_fences_too
    parsed = PM.parse_string("```\n$(echo RAN)\n```\n$(echo OUT)\n")

    assert_equal "```\n$(echo RAN)\n```\nOUT\n", parsed.content
  end

  # --- errors ---

  def test_unmatched_command_raises
    error = assert_raises(PM::ShellExpansionError) { PM.expand_shell('$(echo "hi"') }

    assert_includes error.message, 'Unmatched $('
    assert_includes error.message, 'echo "hi"'
  end

  def test_failed_command_error_carries_details
    error = assert_raises(PM::ShellCommandError) { PM.expand_shell('$(echo oops >&2; exit 3)') }

    assert_equal 3, error.status.exitstatus
    assert_equal 'oops', error.stderr.strip
    assert_equal 'echo oops >&2; exit 3', error.command
    assert_includes error.message, 'exit 3'
    assert_includes error.message, 'oops'
  end

  def test_failed_command_without_stderr_has_one_line_message
    error = assert_raises(PM::ShellCommandError) { PM.expand_shell('$(exit 2)') }

    assert_equal 'Shell command failed (exit 2): exit 2', error.message
  end

  def test_shell_command_error_hierarchy
    assert_operator PM::ShellCommandError, :<, PM::ShellExpansionError
    assert_operator PM::ShellExpansionError, :<, PM::Error
  end

  def test_successful_command_stderr_is_passed_through
    _out, err = capture_io { assert_equal 'ok', PM.expand_shell('$(echo warn >&2; echo ok)') }

    assert_includes err, 'warn'
  end

  # --- still works as before ---

  def test_multiline_command_output
    assert_equal "a\nb", PM.expand_shell('$(echo a; echo b)')
  end

  def test_env_var_inside_command_is_handled_by_the_shell
    ENV['PM_SAFETY_TEST'] = 'v'

    assert_equal 'v', PM.expand_shell('$(echo $PM_SAFETY_TEST)')
  ensure
    ENV.delete('PM_SAFETY_TEST')
  end

  def test_command_spanning_lines
    assert_equal 'x', PM.expand_shell("$(echo \\\n x)")
  end
end
