# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'

# Front-matter YAML errors name the prompt file and the line in that file,
# so a broken included file can be traced.
class PMYamlErrorLocationTest < Minitest::Test
  BROKEN = "---\ntitle: x\nbad: [\n---\nBody\n"

  def setup
    @dir = Dir.mktmpdir('pm-yaml-error')
    File.write(File.join(@dir, 'bad.md'), BROKEN)
    File.write(File.join(@dir, 'outer.md'), "Outer\n<%= include 'bad.md' %>\n")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_yaml_error_names_the_file_and_its_line
    path  = File.join(@dir, 'bad.md')
    error = assert_raises(Psych::SyntaxError) { PM.parse(path) }

    assert_equal path, error.file
    assert_equal 4, error.line
    assert_includes error.message, "(#{path}):"
  end

  def test_yaml_error_in_included_file_names_that_file
    error = assert_raises(Psych::SyntaxError) { PM.parse(File.join(@dir, 'outer.md')).to_s }

    assert_equal File.join(@dir, 'bad.md'), error.file
  end

  def test_yaml_error_line_counts_lines_before_the_fence
    error = assert_raises(Psych::SyntaxError) { PM.parse_string("\n\n#{BROKEN}") }

    assert_nil error.file
    assert_equal 6, error.line
  end
end
