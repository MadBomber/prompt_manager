# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'

# Prompt files are UTF-8 whatever the locale says. Under LANG=C (launchd,
# cron, minimal containers) Encoding.default_external is US-ASCII.
class PMFileEncodingTest < Minitest::Test
  def setup
    @dir = Dir.mktmpdir('pm-encoding')
    File.binwrite(File.join(@dir, 'cafe.md'), "---\ntitle: Café\n---\nHello Café <%= insert 'note.txt' %>\n")
    File.binwrite(File.join(@dir, 'note.txt'), "naïve\n")
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_parse_reads_prompt_files_as_utf8_under_ascii_locale
    parsed = with_default_external('US-ASCII') { PM.parse(File.join(@dir, 'cafe.md')) }

    assert_equal 'Café', parsed.metadata.title
    assert_equal Encoding::UTF_8, parsed.content.encoding
  end

  def test_insert_reads_files_as_utf8_under_ascii_locale
    parsed = PM.parse(File.join(@dir, 'cafe.md'))
    result = with_default_external('US-ASCII') { parsed.to_s }

    assert_equal "Hello Café naïve\n\n", result
    assert result.valid_encoding?
  end

  private

  def with_default_external(encoding)
    saved = Encoding.default_external
    Encoding.default_external = encoding
    yield
  ensure
    Encoding.default_external = saved
  end
end
