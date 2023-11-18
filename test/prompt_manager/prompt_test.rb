# prompt_manager/test/prompt_manager/prompt_test.rb

require_relative '../test_helper'

class PromptTest < Minitest::Test
  # Mock storage adapter that will act as a fake database in tests
  class MockStorageAdapter
    def initialize
      @prompts = {}
    end

    def get(id:)
      @prompts[id.to_sym] || raise("Prompt ID not found")
    end

    def save(id:, text:, parameters:)
      @prompts[id.to_sym] = { text: text, parameters: parameters }
      true
    end

    def delete(id:)
      @prompts.delete(id.to_sym)
    end

    def search(query)
      @prompts.select { |k, v| v[:text].include?(query) }
    end
  end

  def setup
    @storage_adapter = MockStorageAdapter.new

    @storage_adapter.save(
      id:         :test_prompt, 
      text:       "Hello, [NAME]!", 
      parameters: {'name' => 'World'}
    )

    PromptManager::Prompt.storage_adapter = @storage_adapter
  end


  def test_prompt_initialization_raises_argument_error_when_id_blank
    assert_raises ArgumentError do
      PromptManager::Prompt.new(id: '')
    end
  end


  def test_prompt_initialization_raises_argument_error_when_no_storage_adapter_set
    PromptManager::Prompt.storage_adapter = nil
    assert_raises ArgumentError do
      PromptManager::Prompt.new(id: 'test_prompt')
    end
  ensure
    PromptManager::Prompt.storage_adapter = @storage_adapter
  end


  def test_prompt_interpolates_parameters_correctly
    prompt = PromptManager::Prompt.new(id: 'test_prompt')
    assert_equal "Hello, World!", prompt.to_s
  end


  def test_prompt_saves_to_storage
    new_prompt = PromptManager::Prompt.new(
      id:       'new_prompt',
      context:  ['new context']
    )

    new_raw_text    = "How are you, [NAME]?"
    new_parameters  = { 'name' => 'Rubyist' }
    
    new_prompt.db.save(
      id:         'new_prompt', 
      text:       new_raw_text, 
      parameters: new_parameters
    )

    prompt_from_storage = @storage_adapter.get(id: 'new_prompt')

    assert_equal new_raw_text,    prompt_from_storage[:text]
    assert_equal new_parameters,  prompt_from_storage[:parameters]
  end


  def test_prompt_deletes_from_storage
    prompt = PromptManager::Prompt.create(id: 'test_prompt')
    
    assert @storage_adapter.get(id: 'test_prompt') # Verify it exists

    prompt.delete

    assert_raises do
      @storage_adapter.get(id: 'test_prompt') # Should raise "Prompt ID not found"
    end
  end


  def test_prompt_searches_storage
    prompt          = PromptManager::Prompt.new(id: 'test_prompt')
    search_results  = prompt.search('Hello')

    refute_empty search_results
    assert search_results.keys.include?(:test_prompt)
  end
end

__END__
