# frozen_string_literal: true

require_relative 'test_helper'

class PMIncludeChainTest < Minitest::Test
  def teardown
    PM.config.reset!
    PM.reset_directives!
  end

  def test_same_file_may_be_included_twice
    result = PM.parse(fixture('include_twice.md')).to_s

    assert_equal 2, result.scan('--sep--').size
    assert_includes result, "A\n"
    assert_includes result, "C\n"
  end

  def test_includes_tree_lists_both_inclusions
    parsed = PM.parse(fixture('include_twice.md'))
    parsed.to_s

    assert_equal 2, parsed.metadata.includes.size
    assert_equal [1, 1], parsed.metadata.includes.map { |entry| entry[:depth] }
  end

  def test_circular_include_is_still_detected
    error = assert_raises(PM::CircularIncludeError) { PM.parse(fixture('circular_a.md')).to_s }

    assert_kind_of PM::IncludeError, error
    assert_includes error.message, 'circular_a.md'
  end

  def test_render_context_included_holds_only_ancestors
    seen = nil
    PM.register(:spy) { |ctx| seen = ctx.included.dup; '' }

    PM.parse(fixture('with_spy.md')).to_s

    assert_equal [fixture('with_spy.md')], seen.to_a
  end

  def test_non_md_file_can_be_included
    result = PM.parse(fixture('with_include_txt.md')).to_s

    assert_includes result, 'Plain text include.'
    refute_includes result, 'plain.txt'
  end

  def test_include_depth_limit
    PM.config.max_include_depth = 1

    error = assert_raises(PM::IncludeDepthError) { PM.parse(fixture('with_nested_include.md')).to_s }
    assert_includes error.message, 'max_include_depth'
    assert_includes error.message, 'header.md'
  end

  def test_depth_limit_allows_exactly_the_limit
    PM.config.max_include_depth = 2

    assert_includes PM.parse(fixture('with_nested_include.md')).to_s, 'This is the header.'
  end

  def test_nil_depth_limit_is_unlimited
    PM.config.max_include_depth = nil

    assert_includes PM.parse(fixture('with_nested_include.md')).to_s, 'This is the header.'
  end

  def test_include_without_file_context_raises_include_context_error
    error = assert_raises(PM::IncludeContextError) { PM.parse_string("<%= include 'x.md' %>").to_s }

    assert_kind_of PM::IncludeError, error
  end

  def test_insert_of_a_directory_raises_file_not_found
    error = assert_raises(PM::FileNotFoundError) { PM.parse_string("<%= insert '#{FIXTURES}' %>").to_s }

    assert_includes error.message, 'insert: file not found'
  end
end
