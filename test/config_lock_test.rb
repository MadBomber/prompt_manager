# frozen_string_literal: true

require_relative 'test_helper'

class PMConfigLockTest < Minitest::Test
  def teardown
    PM.config.reset!
  end

  def test_unlocked_by_default
    refute_predicate PM.config, :locked?
  end

  def test_lock_prevents_per_file_shell_override
    PM.config.shell = false
    PM.config.lock!

    parsed = PM.parse_string("---\nshell: true\n---\n$(echo RAN)")

    assert_equal '$(echo RAN)', parsed.content
    assert_equal false, parsed.metadata.shell
  end

  def test_lock_prevents_per_file_erb_override
    PM.config.erb = false
    PM.config.lock!

    assert_equal '<%= 1 %>', PM.parse_string("---\nerb: true\n---\n<%= 1 %>").to_s
  end

  def test_lock_forces_globals_on_even_when_file_disables
    PM.config.lock!

    assert_equal '2', PM.parse_string("---\nerb: false\n---\n<%= 1 + 1 %>").to_s
  end

  def test_unlock_restores_per_file_override
    PM.config.lock!
    PM.config.unlock!

    assert_equal '<%= 1 %>', PM.parse_string("---\nerb: false\n---\n<%= 1 %>").to_s
  end

  def test_lock_and_unlock_return_the_config
    assert_same PM.config, PM.config.lock!
    assert_same PM.config, PM.config.unlock!
  end

  def test_reset_unlocks
    PM.config.lock!
    PM.config.reset!

    refute_predicate PM.config, :locked?
  end

  def test_locked_setter
    PM.config.locked = true

    assert_predicate PM.config, :locked?
  end

  def test_new_defaults
    assert_equal 10, PM.config.max_include_depth
    refute_predicate PM.config, :strict_parameters?
  end

  def test_reset_restores_new_defaults
    PM.config.max_include_depth = 1
    PM.config.strict_parameters = true
    PM.config.reset!

    assert_equal 10, PM.config.max_include_depth
    refute_predicate PM.config, :strict_parameters?
  end

  def test_configure_returns_the_config
    assert_same PM.config, PM.configure { |c| c.shell = true }
  end
end
