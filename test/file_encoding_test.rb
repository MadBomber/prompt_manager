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

  # Fails if assign_default_external stops silencing the -w warning.
  # Turns verbose warnings on so the check holds however the file is run.
  def test_switching_default_external_does_not_warn
    with_verbose(true) do
      assert_silent { with_default_external('US-ASCII') {} }
    end
  end

  private

  def with_default_external(encoding)
    saved = Encoding.default_external
    assign_default_external(encoding)
    yield
  ensure
    assign_default_external(saved)
  end

  # Ruby warns on every Encoding.default_external= under -w, which
  # Rake::TestTask passes by default. Silence just this assignment.
  def assign_default_external(encoding)
    with_verbose(nil) { Encoding.default_external = encoding }
  end

  def with_verbose(value)
    saved = $VERBOSE
    $VERBOSE = value
    yield
  ensure
    $VERBOSE = saved
  end
end
