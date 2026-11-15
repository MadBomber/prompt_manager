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


  def test_read_file_converts_to_default_internal_like_file_read
    path = File.join(@dir, 'plain.txt')
    File.binwrite(path, "naïve\n")

    text = with_default_internal('ISO-8859-1') { PM.read_file(path) }

    assert_equal Encoding::ISO_8859_1, text.encoding
    assert_equal "naïve\n", text.encode(Encoding::UTF_8)
  end


  private

  def write(name, text)
    File.binwrite(File.join(@dir, name), BOM + text.b)
  end


  def with_default_internal(encoding)
    verbose = $VERBOSE
    $VERBOSE = nil # setting default_internal warns
    saved = Encoding.default_internal
    Encoding.default_internal = encoding
    yield
  ensure
    Encoding.default_internal = saved
    $VERBOSE = verbose
  end
end
