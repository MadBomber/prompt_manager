# frozen_string_literal: true

require_relative 'test_helper'

class PMFrontMatterValidationTest < Minitest::Test
  def teardown
    PM.config.reset!
  end

  def test_empty_front_matter_block_is_valid
    parsed = PM.parse_string("---\n---\nbody")

    assert_equal 'body', parsed.content
    assert_equal({ shell: true, erb: true }, parsed.metadata.to_h)
  end

  def test_scalar_front_matter_raises_metadata_error
    error = assert_raises(PM::MetadataError) { PM.parse_string("---\njust text\n---\nbody") }
    assert_includes error.message, 'YAML mapping'
    assert_includes error.message, 'String'
  end

  def test_list_front_matter_raises_metadata_error
    assert_raises(PM::MetadataError) { PM.parse_string("---\n- a\n- b\n---\nbody") }
  end

  def test_parameters_must_be_a_mapping
    error = assert_raises(PM::MetadataError) { PM.parse_string("---\nparameters:\n  - code\n---\nx") }
    assert_includes error.message, 'parameters must be a mapping'
  end

  def test_string_flag_values_are_coerced
    assert_equal false, PM.parse_string("---\nerb: 'false'\n---\nx").metadata.erb
    assert_equal true,  PM.parse_string("---\nshell: 'yes'\n---\nx").metadata.shell
    assert_equal false, PM.parse_string("---\nshell: 'OFF'\n---\nx").metadata.shell
    assert_equal true,  PM.parse_string("---\nerb: ' on '\n---\nx").metadata.erb?
  end

  def test_coerced_string_flag_actually_controls_the_stage
    parsed = PM.parse_string("---\nerb: 'false'\n---\n<%= 1 + 1 %>")

    assert_equal '<%= 1 + 1 %>', parsed.to_s
  end

  def test_invalid_flag_value_raises
    error = assert_raises(PM::MetadataError) { PM.parse_string("---\nerb: maybe\n---\nx") }
    assert_includes error.message, 'erb must be true or false'

    assert_raises(PM::MetadataError) { PM.parse_string("---\nshell: 1\n---\nx") }
  end

  def test_nil_flag_uses_global_default
    PM.config.shell = false

    assert_equal false, PM.parse_string("---\nshell:\n---\nx").metadata.shell
  end

  def test_yaml_syntax_error_passes_through
    assert_raises(Psych::SyntaxError) { PM.parse_string("---\nkey: [unclosed\n---\nx") }
  end

  def test_metadata_error_is_a_pm_error
    assert_operator PM::MetadataError, :<, PM::Error
    assert_operator PM::Error, :<, StandardError
  end
end
