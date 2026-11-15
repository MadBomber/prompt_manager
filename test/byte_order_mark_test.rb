# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'

# Editors on Windows often save UTF-8 with a byte order mark. PM drops it
# when reading a file so front matter still parses and no U+FEFF reaches
# the rendered text.
class PMByteOrderMarkTest < Minitest::Test
  BOM = "\xEF\xBB\xBF".b

  def setup
    @dir = Dir.mktmpdir('pm-bom')
    write('bom.md', "---\ntitle: Hi\n---\nBody\n")
    write('note.txt', "naïve\n")
    write('parent.md', "Before <%= include 'bom.md' %> <%= insert 'note.txt' %>\n")
  end


  def teardown
    FileUtils.remove_entry(@dir)
  end


  def test_parse_strips_bom_before_front_matter
    parsed = PM.parse(File.join(@dir, 'bom.md'))

    assert_equal 'Hi', parsed.metadata.title
    assert_equal "Body\n", parsed.to_s
  end


  def test_include_and_insert_strip_bom
    result = PM.parse(File.join(@dir, 'parent.md')).to_s

    assert_equal "Before Body\n naïve\n\n", result
    refute_includes result, "\uFEFF"
  end

  private

  def write(name, text)
    File.binwrite(File.join(@dir, name), BOM + text.b)
  end
end
