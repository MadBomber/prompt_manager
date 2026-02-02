# frozen_string_literal: true

require_relative 'test_helper'

class PMParseTest < Minitest::Test
  def test_parse_extracts_metadata_and_content
    input = "---\ntitle: Hello\n---\nSome content\n"
    parsed = PM.parse(input)

    assert_equal 'Hello', parsed.metadata.title
    assert_equal "Some content\n", parsed.content
  end

  def test_parse_with_no_metadata
    parsed = PM.parse("Just plain text")

    assert_nil parsed.metadata.title
    assert_equal "Just plain text", parsed.content
  end

  def test_parse_with_multiple_metadata_fields
    input = "---\ntitle: Test\nmodel: gpt-4\ntemperature: 0.5\n---\nContent\n"
    parsed = PM.parse(input)

    assert_equal 'Test', parsed.metadata.title
    assert_equal 'gpt-4', parsed.metadata.model
    assert_equal 0.5, parsed.metadata.temperature
  end

  def test_parse_with_leading_whitespace
    input = "\n\n---\ntitle: Hello\n---\nContent\n"
    parsed = PM.parse(input)

    assert_equal 'Hello', parsed.metadata.title
  end

  def test_bracket_accessor_delegates_to_metadata
    parsed = PM.parse("---\ntitle: Test\n---\nContent\n")

    assert_equal 'Test', parsed['title']
  end

  def test_metadata_defaults_shell_to_true
    parsed = PM.parse("---\ntitle: Test\n---\nContent\n")

    assert_equal true, parsed.metadata.shell
  end

  def test_metadata_defaults_erb_to_true
    parsed = PM.parse("---\ntitle: Test\n---\nContent\n")

    assert_equal true, parsed.metadata.erb
  end

  def test_parse_strips_html_comments
    input = "---\ntitle: Test\n---\nBefore <!-- comment --> after\n"
    parsed = PM.parse(input)

    refute_includes parsed.content, 'comment'
    assert_includes parsed.content, 'Before'
    assert_includes parsed.content, 'after'
  end

  def test_parse_expands_shell_vars
    ENV['PM_TEST_PARSE'] = 'expanded'
    parsed = PM.parse("---\ntitle: Test\n---\nValue: $PM_TEST_PARSE\n")

    assert_includes parsed.content, 'Value: expanded'
  ensure
    ENV.delete('PM_TEST_PARSE')
  end

  def test_parse_skips_shell_when_disabled
    parsed = PM.parse("---\ntitle: Test\nshell: false\n---\nValue: $USER\n")

    assert_includes parsed.content, '$USER'
  end

  def test_parse_strips_comments_before_front_matter
    input = "<!-- comment -->\n---\ntitle: Found\n---\nContent\n"
    parsed = PM.parse(input)

    assert_equal 'Found', parsed.metadata.title
  end
end

class PMParseFileTest < Minitest::Test
  def test_parse_accepts_pathname
    require 'pathname'
    parsed = PM.parse(Pathname.new(fixture('simple.md')))

    assert_equal 'Simple Prompt', parsed.metadata.title
    assert_equal FIXTURES, parsed.metadata.directory
    assert_equal 'simple.md', parsed.metadata.name
  end

  def test_parse_extracts_metadata_from_file
    parsed = PM.parse(fixture('simple.md'))

    assert_equal 'Simple Prompt', parsed.metadata.title
    assert_equal 'openai', parsed.metadata.provider
    assert_equal 'gpt-4', parsed.metadata.model
  end

  def test_parse_extracts_content
    parsed = PM.parse(fixture('simple.md'))

    assert_includes parsed.content, 'simple prompt with no parameters'
  end

  def test_parse_adds_directory_to_metadata
    parsed = PM.parse(fixture('simple.md'))

    assert_equal FIXTURES, parsed.metadata.directory
  end

  def test_parse_adds_name_to_metadata
    parsed = PM.parse(fixture('simple.md'))

    assert_equal 'simple.md', parsed.metadata.name
  end

  def test_parse_adds_created_at_to_metadata
    parsed = PM.parse(fixture('simple.md'))

    assert_instance_of Time, parsed.metadata.created_at
  end

  def test_parse_adds_modified_at_to_metadata
    parsed = PM.parse(fixture('simple.md'))

    assert_instance_of Time, parsed.metadata.modified_at
  end

  def test_parse_with_no_metadata
    parsed = PM.parse(fixture('no_metadata.md'))

    assert_equal FIXTURES, parsed.metadata.directory
    assert_equal 'no_metadata.md', parsed.metadata.name
    assert_includes parsed.content, 'Just plain content'
  end
end

class PMParseShorthandTest < Minitest::Test
  def setup
    PM.config.prompts_dir = FIXTURES
  end

  def teardown
    PM.config.reset!
  end

  # --- Symbol source ---

  def test_parse_accepts_symbol
    parsed = PM.parse(:simple)

    assert_equal 'Simple Prompt', parsed.metadata.title
  end

  def test_parse_symbol_adds_directory_to_metadata
    parsed = PM.parse(:simple)

    assert_equal FIXTURES, parsed.metadata.directory
  end

  def test_parse_symbol_adds_name_to_metadata
    parsed = PM.parse(:simple)

    assert_equal 'simple.md', parsed.metadata.name
  end

  def test_parse_symbol_adds_created_at_to_metadata
    parsed = PM.parse(:simple)

    assert_instance_of Time, parsed.metadata.created_at
  end

  def test_parse_symbol_adds_modified_at_to_metadata
    parsed = PM.parse(:simple)

    assert_instance_of Time, parsed.metadata.modified_at
  end

  def test_parse_symbol_extracts_content
    parsed = PM.parse(:simple)

    assert_includes parsed.content, 'simple prompt with no parameters'
  end

  def test_parse_symbol_with_subdirectory_fixture
    parsed = PM.parse(:'includes/header')

    assert_equal 'header.md', parsed.metadata.name
  end

  # --- Single word string source ---

  def test_parse_accepts_single_word
    parsed = PM.parse('simple')

    assert_equal 'Simple Prompt', parsed.metadata.title
  end

  def test_parse_single_word_adds_directory_to_metadata
    parsed = PM.parse('simple')

    assert_equal FIXTURES, parsed.metadata.directory
  end

  def test_parse_single_word_adds_name_to_metadata
    parsed = PM.parse('simple')

    assert_equal 'simple.md', parsed.metadata.name
  end

  def test_parse_single_word_adds_file_timestamps
    parsed = PM.parse('simple')

    assert_instance_of Time, parsed.metadata.created_at
    assert_instance_of Time, parsed.metadata.modified_at
  end

  def test_parse_single_word_extracts_content
    parsed = PM.parse('simple')

    assert_includes parsed.content, 'simple prompt with no parameters'
  end

  # --- Single word detection edge cases ---

  def test_multiword_string_not_treated_as_file
    parsed = PM.parse("Hello world")

    assert_nil parsed.metadata.title
    assert_equal "Hello world", parsed.content
  end

  def test_string_with_dots_not_treated_as_single_word
    parsed = PM.parse("some.thing")

    assert_nil parsed.metadata.title
    assert_equal "some.thing", parsed.content
  end

  def test_string_with_spaces_not_treated_as_single_word
    parsed = PM.parse("not a word")

    assert_nil parsed.metadata.title
    assert_equal "not a word", parsed.content
  end

  def test_string_with_newline_not_treated_as_single_word
    parsed = PM.parse("line1\nline2")

    assert_nil parsed.metadata.title
    assert_equal "line1\nline2", parsed.content
  end

  def test_string_with_yaml_not_treated_as_single_word
    parsed = PM.parse("---\ntitle: Test\n---\nContent\n")

    assert_equal 'Test', parsed.metadata.title
  end

  def test_single_word_with_underscores_treated_as_file
    parsed = PM.parse('no_metadata')

    assert_equal FIXTURES, parsed.metadata.directory
    assert_equal 'no_metadata.md', parsed.metadata.name
  end
end

class PMStripCommentsTest < Minitest::Test
  def test_strips_inline_html_comment
    parsed = PM.parse(fixture('with_comments.md'))

    assert_includes parsed.content, 'Before comment.'
    assert_includes parsed.content, 'After comment.'
    refute_includes parsed.content, 'This is a comment'
  end

  def test_strips_multiline_html_comment
    parsed = PM.parse(fixture('with_comments.md'))

    refute_includes parsed.content, 'Multi'
    refute_includes parsed.content, 'line'
    assert_includes parsed.content, 'End.'
  end

  def test_strips_comment_before_front_matter
    parsed = PM.parse(fixture('comment_in_metadata.md'))

    assert_equal 'Metadata After Comment', parsed.metadata.title
    assert_includes parsed.content, 'Content here.'
  end

  def test_strip_comments_available_directly
    input = "Hello <!-- hidden --> world"
    result = PM.strip_comments(input)

    assert_equal "Hello  world", result
  end

  def test_no_comments_passes_through
    input = "No comments here"
    result = PM.strip_comments(input)

    assert_equal "No comments here", result
  end
end

class PMBothDisabledTest < Minitest::Test
  def test_both_disabled_preserves_content
    parsed = PM.parse(fixture('both_disabled.md'))
    result = parsed.to_s

    assert_includes result, '$USER'
    assert_includes result, '<%= name %>'
    assert_includes result, '$(echo should not run)'
  end
end
