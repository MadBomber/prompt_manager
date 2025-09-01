# frozen_string_literal: true

require_relative '../../test_helper'

class TestRemovedKeywordsBug < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @adapter = PromptManager::Storage::FileSystemAdapter.config do |config|
      config.prompts_dir = @temp_dir
    end.new
    
    PromptManager::Prompt.storage_adapter = @adapter
  end

  def teardown
    FileUtils.remove_entry(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def test_removed_keywords_are_not_included_in_parameters
    prompt_id = 'test_prompt'
    
    # Step 1: Create a prompt with two keywords
    initial_text = "Hello [NAME], you are [AGE] years old."
    File.write(File.join(@temp_dir, "#{prompt_id}.txt"), initial_text)
    
    # Step 2: Save parameters for both keywords (simulating previous usage)
    params = {
      "[NAME]" => ["Alice", "Bob"],
      "[AGE]" => ["25", "30"]
    }
    File.write(
      File.join(@temp_dir, "#{prompt_id}.json"), 
      JSON.pretty_generate(params)
    )
    
    # Step 3: Update prompt text to remove [AGE] keyword
    updated_text = "Hello [NAME], welcome!"
    File.write(File.join(@temp_dir, "#{prompt_id}.txt"), updated_text)
    
    # Step 4: Load the prompt and check parameters
    prompt = PromptManager::Prompt.new(id: prompt_id)
    
    # The parameters should only include [NAME], not [AGE]
    assert_includes prompt.parameters.keys, "[NAME]"
    refute_includes prompt.parameters.keys, "[AGE]", 
      "Removed keyword [AGE] should not be in parameters"
    
    # Verify the historical values are preserved for existing keywords
    assert_equal ["Alice", "Bob"], prompt.parameters["[NAME]"]
  end
  
  def test_new_keywords_start_with_empty_array
    prompt_id = 'new_keyword_test'
    
    # Create a prompt with a keyword that has no JSON history
    text = "Testing [NEW_KEYWORD] here."
    File.write(File.join(@temp_dir, "#{prompt_id}.txt"), text)
    
    prompt = PromptManager::Prompt.new(id: prompt_id)
    
    # New keywords should have empty array as value
    assert_equal [], prompt.parameters["[NEW_KEYWORD]"]
  end
  
  def test_keywords_with_existing_history_preserve_values
    prompt_id = 'history_test'
    
    # Create prompt and JSON with history
    text = "Hello [NAME]!"
    File.write(File.join(@temp_dir, "#{prompt_id}.txt"), text)
    
    params = {
      "[NAME]" => ["Alice", "Bob", "Charlie"]
    }
    File.write(
      File.join(@temp_dir, "#{prompt_id}.json"),
      JSON.pretty_generate(params)
    )
    
    prompt = PromptManager::Prompt.new(id: prompt_id)
    
    # Should preserve the historical values
    assert_equal ["Alice", "Bob", "Charlie"], prompt.parameters["[NAME]"]
  end
end