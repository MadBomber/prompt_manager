# frozen_string_literal: true

require_relative 'test_helper'

class PMMetadataTest < Minitest::Test
  def test_dot_notation_access
    parsed = PM.parse(fixture('simple.md'))

    assert_equal 'Simple Prompt', parsed.metadata.title
    assert_equal 'openai', parsed.metadata.provider
    assert_equal 'gpt-4', parsed.metadata.model
  end

  def test_predicate_methods_for_boolean_true
    parsed = PM.parse(fixture('simple.md'))

    assert_equal true, parsed.metadata.shell?
    assert_equal true, parsed.metadata.erb?
  end

  def test_predicate_methods_for_boolean_false
    parsed = PM.parse(fixture('shell_disabled.md'))

    assert_equal false, parsed.metadata.shell?
  end

  def test_predicate_methods_for_erb_false
    parsed = PM.parse(fixture('erb_disabled.md'))

    assert_equal false, parsed.metadata.erb?
  end

  def test_non_boolean_keys_have_no_predicate
    parsed = PM.parse(fixture('simple.md'))

    refute_respond_to parsed.metadata, :title?
  end

  def test_date_values_parsed_as_date_objects
    parsed = PM.parse(fixture('with_dates.md'))

    assert_instance_of Date, parsed.metadata.created
    assert_equal Date.new(2026, 2, 1), parsed.metadata.created
  end

  def test_time_values_parsed_as_time_objects
    parsed = PM.parse(fixture('with_dates.md'))

    assert_instance_of Time, parsed.metadata.updated
  end

  def test_parameters_accessible_via_dot_notation
    parsed = PM.parse(fixture('with_parameters.md'))

    assert_equal 'ruby', parsed.metadata.parameters['language']
    assert_nil parsed.metadata.parameters['code']
    assert_equal 'concise', parsed.metadata.parameters['style']
  end
end
