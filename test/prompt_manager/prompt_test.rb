# prompt_manager/test/prompt_manager/prompt_test.rb

require_relative '../test_helper'

class PromptTest < Minitest::Test
  # Mock storage adapter that will act as a fake database in tests
  class MockStorageAdapter
    @@db = {} # generic database - a collection of prompts

    # NOTE: storage adapter can add extra class
    #       or instance methods available to the Prompt class
    #
    class << self
      def extra(prompt_id)
        new.extra(prompt_id)
      end
    end

    attr_accessor :id, :text, :parameters 
    
    def db = @@db

    def initialize
      @id         = nil # String name of the prompt
      @text       = nil # String raw text with parameters
      @parameters = nil # Hash for current prompt
    end


    def get(id:)
      raise("Prompt ID not found") unless @@db.has_key? id

      record = @@db[id]

      @id         = id
      @text       = record[:text]
      @parameters = record[:parameters]

      record
    end


    def save(id: @id, text: @text, parameters: @parameters)
      @@db[id] = { text: text, parameters: parameters }
      true
    end


    def delete(id: @id)
      raise("What") unless @@db.has_key?(id)
      db.delete(id)
    end


    def search(query)
      @@db.select { |k, v| v[:text].include?(query) }
    end


    def extra(prompt_id)
      "Hello #{prompt_id}"
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
    assert_raises ArgumentError do
      PromptManager::Prompt.new(id: 'test_prompt')
    end
  ensure
    PromptManager::Prompt.storage_adapter = @storage_adapter
  end


  ##########################################
  def test_prompt_interpolates_parameters_correctly
    prompt    = PromptManager::Prompt.new(id: 'test_prompt')
    expected  = "Hello, World!"

    assert_equal expected, prompt.to_s
  end


  def test_access_to_keywords
    prompt = PromptManager::Prompt.new(id: 'test_prompt')
    assert_equal ['[LANGUAGE]', '[NAME]'], prompt.keywords
  end


  def test_access_to_directives
    prompt    = PromptManager::Prompt.new(id: 'test_prompt')
    expected  = [
      ['TextToSpeech', 'English World']
    ]

    # NOTE: directives are collected after parameter substitution

    assert_equal expected, prompt.directives
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

    assert_raises do
      PromptManager::Prompt.get(id: 'test_prompt') # Should raise "Prompt ID not found"
    end
  end


  ##########################################
  def test_prompt_searches_storage
    search_results  = PromptManager::Prompt.search('Hello')

    refute_empty search_results
    assert search_results.keys.include?('test_prompt')
  end


  ##########################################
  def test_extra
    class_result  = PromptManager::Prompt.extra("World")
    result        = PromptManager::Prompt.create(id: 'World').extra("World")

    assert_equal class_result, result
    assert_equal result, "Hello World"
  end
end

__END__
