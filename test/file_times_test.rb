# frozen_string_literal: true

require_relative 'test_helper'

class PMFileTimesTest < Minitest::Test
  FakeStat = Struct.new(:mtime, :ctime) do
    def birthtime
      raise NotImplementedError, 'birthtime() function is unimplemented on this machine'
    end
  end

  def test_birthtime_helper_falls_back_to_ctime_when_unimplemented
    ctime = Time.at(1_000)

    assert_equal ctime, PM.send(:birthtime, FakeStat.new(Time.at(2_000), ctime))
  end

  def test_birthtime_helper_falls_back_when_stat_has_no_birthtime_method
    stat = Struct.new(:ctime).new(Time.at(3_000))

    assert_equal Time.at(3_000), PM.send(:birthtime, stat)
  end

  def test_created_at_uses_birthtime_when_available
    parsed = PM.parse(fixture('simple.md'))

    assert_equal File.stat(fixture('simple.md')).birthtime, parsed.metadata.created_at
    assert_equal File.stat(fixture('simple.md')).mtime, parsed.metadata.modified_at
  end

  def test_missing_file_raises_errno_enoent
    assert_raises(Errno::ENOENT) { PM.parse('definitely_missing_prompt_file.md') }
  end
end
