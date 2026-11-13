# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'

# ERB errors name the prompt file they came from, so a failure inside an
# included file can be traced to that file.
class PMErbFilenameTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('pm-erb-filename')
    File.write(File.join(@dir, 'outer.md'), "Outer\n<%= include 'inner.md' %>\n")
    File.write(File.join(@dir, 'inner.md'), "Inner\n<%= nil.foo %>\n")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_erb_error_backtrace_names_the_included_file
    error = assert_raises(NoMethodError) { PM.parse(File.join(@dir, 'outer.md')).to_s }
    inner = File.join(@dir, 'inner.md')

    assert(error.backtrace.any? { |frame| frame.start_with?("#{inner}:2:") },
           "expected #{inner}:2 in backtrace:\n#{error.backtrace.first(5).join("\n")}")
  end

  def test_erb_error_from_string_prompt_keeps_erb_label
    error = assert_raises(NoMethodError) { PM.parse_string("x\n<%= nil.foo %>\n").to_s }

    assert_match(/\A\(erb\):2:/, error.backtrace.first)
  end
end
