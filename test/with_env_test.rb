# frozen_string_literal: true

require_relative 'test_helper'

# Guards the `with_env` test helper so every ENV-touching test can rely on it
# to save and restore keys instead of unconditionally deleting them.
class WithEnvHelperTest < Minitest::Test
  def test_restores_a_preexisting_value
    ENV['PM_WITH_ENV_PRE'] = 'original'

    with_env('PM_WITH_ENV_PRE' => 'temporary') do
      assert_equal 'temporary', ENV['PM_WITH_ENV_PRE']
    end

    assert_equal 'original', ENV['PM_WITH_ENV_PRE']
  ensure
    ENV.delete('PM_WITH_ENV_PRE')
  end

  def test_restores_a_key_that_was_unset
    ENV.delete('PM_WITH_ENV_UNSET')

    with_env('PM_WITH_ENV_UNSET' => 'temporary') do
      assert_equal 'temporary', ENV['PM_WITH_ENV_UNSET']
    end

    refute ENV.key?('PM_WITH_ENV_UNSET')
  end

  def test_nil_value_deletes_the_key_for_the_block_then_restores
    ENV['PM_WITH_ENV_DEL'] = 'original'

    with_env('PM_WITH_ENV_DEL' => nil) do
      refute ENV.key?('PM_WITH_ENV_DEL')
    end

    assert_equal 'original', ENV['PM_WITH_ENV_DEL']
  ensure
    ENV.delete('PM_WITH_ENV_DEL')
  end

  def test_restores_even_when_the_block_raises
    ENV['PM_WITH_ENV_RAISE'] = 'original'

    assert_raises(RuntimeError) do
      with_env('PM_WITH_ENV_RAISE' => 'temporary') { raise 'boom' }
    end

    assert_equal 'original', ENV['PM_WITH_ENV_RAISE']
  ensure
    ENV.delete('PM_WITH_ENV_RAISE')
  end
end
