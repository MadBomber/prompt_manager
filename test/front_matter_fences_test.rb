# frozen_string_literal: true

require_relative 'test_helper'

# Front matter fences are `---` on lines of their own, with optional trailing
# blanks and an optional CR (Windows line endings).
class PMFrontMatterFencesTest < Minitest::Test
  def test_crlf_front_matter_is_parsed
    parsed = PM.parse_string("---\r\ntitle: Hi\r\n---\r\nBody\r\n")

    assert_equal 'Hi', parsed.metadata.title
    assert_equal "Body\r\n", parsed.content
  end

  def test_indented_fence_inside_block_scalar_does_not_close_front_matter
    parsed = PM.parse_string("---\nnote: |\n  a\n  ---\n  b\ndescription: kept\n---\nBody\n")

    assert_equal "a\n---\nb\n", parsed.metadata.note
    assert_equal 'kept', parsed.metadata.description
    assert_equal "Body\n", parsed.content
  end

  def test_value_ending_in_dashes_does_not_close_front_matter
    parsed = PM.parse_string("---\ntitle: a---\ndescription: kept\n---\nBody\n")

    assert_equal 'a---', parsed.metadata.title
    assert_equal 'kept', parsed.metadata.description
    assert_equal "Body\n", parsed.content
  end

  def test_trailing_blanks_after_fences_are_allowed
    parsed = PM.parse_string("--- \ntitle: Hi\n---\t\nBody\n")

    assert_equal 'Hi', parsed.metadata.title
    assert_equal "Body\n", parsed.content
  end

  def test_empty_front_matter
    parsed = PM.parse_string("---\n---\nBody\n")

    assert_nil parsed.metadata.title
    assert_equal "Body\n", parsed.content
  end

  def test_closing_fence_at_end_of_input
    parsed = PM.parse_string("---\ntitle: Hi\n---")

    assert_equal 'Hi', parsed.metadata.title
    assert_equal '', parsed.content
  end

  def test_opening_fence_must_be_on_its_own_line
    parsed = PM.parse_string("---title: x\n---\nBody\n")

    assert_nil parsed.metadata.title
    assert_equal "---title: x\n---\nBody\n", parsed.content
  end
end
