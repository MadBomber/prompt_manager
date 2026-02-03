# frozen_string_literal: true

require_relative 'test_helper'

class PMToSTest < Minitest::Test
  def test_to_s_with_no_parameters_no_erb
    parsed = PM.parse(fixture('simple.md'))
    result = parsed.to_s

    assert_includes result, 'simple prompt with no parameters'
  end

  def test_to_s_with_erb_and_no_parameters
    parsed = PM.parse(fixture('with_erb.md'))
    result = parsed.to_s

    assert_includes result, Time.now.strftime('%A')
    assert_includes result, '4'
  end

  def test_to_s_with_all_defaults
    parsed = PM.parse(fixture('all_defaults.md'))
    result = parsed.to_s

    assert_includes result, 'hello, world!'
  end

  def test_to_s_overrides_defaults
    parsed = PM.parse(fixture('all_defaults.md'))
    result = parsed.to_s('greeting' => 'hi', 'name' => 'bob')

    assert_includes result, 'hi, bob!'
  end

  def test_to_s_with_symbol_keys
    parsed = PM.parse(fixture('all_defaults.md'))
    result = parsed.to_s(greeting: 'hey', name: 'sue')

    assert_includes result, 'hey, sue!'
  end

  def test_to_s_with_required_parameter_provided
    parsed = PM.parse(fixture('with_parameters.md'))
    result = parsed.to_s('code' => 'puts "hi"')

    assert_includes result, 'ruby'
    assert_includes result, 'concise'
    assert_includes result, 'puts "hi"'
  end

  def test_to_s_raises_on_missing_required_parameter
    parsed = PM.parse(fixture('with_parameters.md'))

    error = assert_raises(ArgumentError) { parsed.to_s }
    assert_includes error.message, 'code'
  end

  def test_to_s_with_no_metadata
    parsed = PM.parse(fixture('no_metadata.md'))
    result = parsed.to_s

    assert_includes result, 'Just plain content'
  end
end

class PMErbFlagTest < Minitest::Test
  def test_erb_disabled_skips_erb_processing
    parsed = PM.parse(fixture('erb_disabled.md'))
    result = parsed.to_s

    assert_includes result, '<%= name %>'
  end

  def test_erb_enabled_by_default
    parsed = PM.parse(fixture('all_defaults.md'))
    result = parsed.to_s

    assert_includes result, 'hello, world!'
    refute_includes result, '<%='
  end

  def test_erb_disabled_ignores_parameter_values
    parsed = PM.parse(fixture('erb_disabled.md'))
    result = parsed.to_s('name' => 'override')

    assert_includes result, '<%= name %>'
  end

  def test_erb_flag_in_metadata
    parsed = PM.parse(fixture('erb_disabled.md'))

    assert_equal false, parsed.metadata.erb
    assert_equal false, parsed.metadata.erb?
  end
end
