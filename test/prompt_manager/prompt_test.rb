# prompt_manager/test/prompt_manager/prompt_test.rb

require 'test_helper'

class PromptTest < Minitest::Test

  def test_prompt_initialization_with_invalid_id
    assert_raises ArgumentError do
      PromptManager::Prompt.new(id: nil)
    end
  end

  def test_prompt_delete_non_existent
    prompt = PromptManager::Prompt.new(id: 'test_prompt')
    prompt.db.delete(id: 'test_prompt') # Ensure the prompt is deleted
    assert_raises RuntimeError do
      prompt.delete
    end
  end


  ##########################################
  def setup
    @storage_adapter = MockStorageAdapter.new

    @storage_adapter.save(
      id:         'test_prompt',
      parameters: {
        '[NAME]'      => ['World'],
        '[LANGUAGE]'  => ['English']
      },
      text: <<~EOS
        # First Comment
        //TextToSpeech [LANGUAGE] [NAME]
        Hello, [NAME]!
        __END__
        Last Comment
      EOS
    )

    PromptManager::Prompt.storage_adapter = @storage_adapter
  end


  ##########################################
  def test_class_constants
    assert_equal '#',   PromptManager::Prompt::COMMENT_SIGNAL
    assert_equal '//',  PromptManager::Prompt::DIRECTIVE_SIGNAL
  end


  ##########################################
  def test_prompt_initialization_raises_argument_error_when_id_blank
    assert_raises ArgumentError do
      PromptManager::Prompt.new(id: '')
    end
  end


  ##########################################
  def test_prompt_initialization_raises_argument_error_when_no_storage_adapter_set
    PromptManager::Prompt.storage_adapter = nil
    assert_raises(ArgumentError, 'storage_adapter is not set') do
      PromptManager::Prompt.new(id: 'test_prompt')
    end
  ensure
    PromptManager::Prompt.storage_adapter = @storage_adapter
  end


  ##########################################
  def test_prompt_initialization_with_valid_id
    prompt = PromptManager::Prompt.new(id: 'test_prompt')
    assert_equal 'test_prompt', prompt.id
  end

  def test_prompt_to_s_method
    prompt = PromptManager::Prompt.new(id: 'test_prompt')
    # Build removes comments and directives, but keeps __END__ etc.
    # EDIT: Now removes __END__ and subsequent lines.
    expected = "Hello, World!"
    assert_equal expected, prompt.to_s
  end


  ##########################################
  def test_prompt_saves_to_storage
    new_prompt_id         = 'new_prompt'
    new_prompt_text       = "How are you, [NAME]?"
    new_prompt_parameters = { 'name' => 'Rubyist' }

    PromptManager::Prompt.create(
      id:         new_prompt_id,
      text:       new_prompt_text,
      parameters: new_prompt_parameters
    )

    prompt_from_storage = @storage_adapter.get(id: 'new_prompt')

    assert_equal new_prompt_text,       prompt_from_storage[:text]
    assert_equal new_prompt_parameters, prompt_from_storage[:parameters]
  end


  ##########################################
  def test_prompt_deletes_from_storage
    prompt = PromptManager::Prompt.create(id: 'test_prompt')

    assert PromptManager::Prompt.get(id: 'test_prompt') # Verify it exists

    prompt.delete

    assert_raises(ArgumentError) do
      PromptManager::Prompt.get(id: 'test_prompt') # Should raise error when prompt not found
    end
  end


  ##########################################
  def test_prompt_searches_storage
    search_results  = PromptManager::Prompt.search('Hello')

    refute_empty search_results
    assert_includes search_results, 'test_prompt'
  end
end

__END__
