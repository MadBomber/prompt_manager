# frozen_string_literal: true

require_relative 'test_helper'

class PMConfigurationTest < Minitest::Test
  def teardown
    PM.config.reset!
  end

  # --- Singleton & configure ---

  def test_config_returns_configuration_instance
    assert_instance_of PM::Configuration, PM.config
  end

  def test_config_returns_same_instance
    assert_same PM.config, PM.config
  end

  def test_configure_yields_config
    yielded = nil
    PM.configure { |c| yielded = c }

    assert_same PM.config, yielded
  end

  # --- Default values ---

  def test_default_prompts_dir_is_empty_string
    assert_equal '', PM.config.prompts_dir
  end

  def test_default_shell_is_true
    assert_equal true, PM.config.shell
  end

  def test_default_erb_is_true
    assert_equal true, PM.config.erb
  end

  # --- reset! ---

  def test_reset_restores_prompts_dir
    PM.config.prompts_dir = '/some/path'
    PM.config.reset!

    assert_equal '', PM.config.prompts_dir
  end

  def test_reset_restores_shell
    PM.config.shell = false
    PM.config.reset!

    assert_equal true, PM.config.shell
  end

  def test_reset_restores_erb
    PM.config.erb = false
    PM.config.reset!

    assert_equal true, PM.config.erb
  end

  # --- prompts_dir with relative paths ---

  def test_prompts_dir_prepends_to_relative_path
    PM.config.prompts_dir = FIXTURES
    parsed = PM.parse('simple.md')

    assert_equal 'Simple Prompt', parsed.metadata.title
    assert_equal FIXTURES, parsed.metadata.directory
  end

  def test_prompts_dir_with_subdirectory
    PM.config.prompts_dir = FIXTURES
    parsed = PM.parse('includes/header.md')

    assert_equal File.join(FIXTURES, 'includes'), parsed.metadata.directory
    assert_equal 'header.md', parsed.metadata.name
  end

  # --- prompts_dir with absolute paths ---

  def test_absolute_path_bypasses_prompts_dir
    PM.config.prompts_dir = '/nonexistent/directory'
    parsed = PM.parse(fixture('simple.md'))

    assert_equal 'Simple Prompt', parsed.metadata.title
  end

  def test_absolute_pathname_bypasses_prompts_dir
    PM.config.prompts_dir = '/nonexistent/directory'
    parsed = PM.parse(Pathname.new(fixture('simple.md')))

    assert_equal 'Simple Prompt', parsed.metadata.title
  end

  # --- prompts_dir empty string ---

  def test_empty_prompts_dir_does_not_alter_path
    PM.config.prompts_dir = ''
    parsed = PM.parse(fixture('simple.md'))

    assert_equal 'Simple Prompt', parsed.metadata.title
  end

  # --- Global shell config ---

  def test_global_shell_false_disables_shell_expansion
    ENV['PM_TEST_CONF'] = 'should_not_expand'
    PM.config.shell = false
    parsed = PM.parse("---\ntitle: Test\n---\nValue: $PM_TEST_CONF\n")

    assert_includes parsed.content, '$PM_TEST_CONF'
  ensure
    ENV.delete('PM_TEST_CONF')
  end

  def test_global_shell_false_applies_to_files
    PM.config.shell = false
    parsed = PM.parse(fixture('simple.md'))

    assert_equal false, parsed.metadata.shell
  end

  # --- Global erb config ---

  def test_global_erb_false_disables_erb
    PM.config.erb = false
    parsed = PM.parse("---\ntitle: Test\n---\nContent\n")

    assert_equal false, parsed.metadata.erb
  end

  def test_global_erb_false_applies_to_files
    PM.config.erb = false
    parsed = PM.parse(fixture('all_defaults.md'))

    assert_equal false, parsed.metadata.erb
  end

  # --- Per-file metadata overrides global config ---

  def test_per_file_shell_true_overrides_global_false
    PM.config.shell = false
    parsed = PM.parse("---\ntitle: Test\nshell: true\n---\nContent\n")

    assert_equal true, parsed.metadata.shell
  end

  def test_per_file_shell_false_overrides_global_true
    PM.config.shell = true
    parsed = PM.parse("---\ntitle: Test\nshell: false\n---\nValue: $USER\n")

    assert_includes parsed.content, '$USER'
  end

  def test_per_file_erb_true_overrides_global_false
    PM.config.erb = false
    parsed = PM.parse("---\ntitle: Test\nerb: true\n---\nContent\n")

    assert_equal true, parsed.metadata.erb
  end

  def test_per_file_erb_false_overrides_global_true
    PM.config.erb = true
    parsed = PM.parse(fixture('erb_disabled.md'))

    assert_equal false, parsed.metadata.erb
  end
end
