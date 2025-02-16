# prompt_manager/test/prompt_manager_test.rb

require 'test_helper'

class TestPromptManager < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::PromptManager::VERSION
  end

  def test_prompt_manager_error_handling
    assert_raises(PromptManager::Error) do
      raise PromptManager::Error, "This is a test error"
    end
  end
end

__END__

