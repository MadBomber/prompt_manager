# prompt_manager/test/prompt_manager/prompt_test.rb

require 'test_helper'
require 'fileutils'
require 'tmpdir'
require 'pathname'

debug_me{[
  "PromptManager::Prompt.storage_adapter"
]}


class PromptTest < Minitest::Test
  # Save original adapter settings to restore them after tests
  def setup
    # Save original settings
    @original_prompts_dir = PromptManager::Storage::FileSystemAdapter.prompts_dir

    # Create a dedicated test directory for each test
    @test_dir = Dir.mktmpdir('prompt_test_')
    @test_prompts_dir = Pathname.new(File.join(@test_dir, 'prompts'))
    FileUtils.mkdir_p(@test_prompts_dir)

    # Temporarily change the prompts_dir for all tests in this run
    # We're using the same adapter class, just pointing it to a different directory
    PromptManager::Storage::FileSystemAdapter.prompts_dir = @test_prompts_dir
  end

  def teardown
    # Restore original adapter settings and clean up test directory
    PromptManager::Storage::FileSystemAdapter.prompts_dir = @original_prompts_dir
    FileUtils.remove_entry(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  def test_prompt_initialization_with_invalid_id
    assert_raises ArgumentError do
      PromptManager::Prompt.new(id: nil, context: [], directives_processor: PromptManager::DirectiveProcessor.new)
    end
  end

  def test_class_constants
    assert_equal '#',   PromptManager::Prompt::COMMENT_SIGNAL
    assert_equal '//',  PromptManager::Prompt::DIRECTIVE_SIGNAL
  end

  def test_prompt_initialization_raises_argument_error_when_id_blank
    assert_raises ArgumentError do
      PromptManager::Prompt.new(id: '', context: [], directives_processor: PromptManager::DirectiveProcessor.new)
    end
  end

  def test_prompt_initialization_raises_argument_error_when_no_storage_adapter_set
    original_adapter = PromptManager::Prompt.storage_adapter
    begin
      PromptManager::Prompt.storage_adapter = nil
      assert_raises(ArgumentError, 'storage_adapter is not set') do
        PromptManager::Prompt.new(id: 'test_prompt', context: [], directives_processor: PromptManager::DirectiveProcessor.new)
      end
    ensure
      PromptManager::Prompt.storage_adapter = original_adapter
    end
  end

  def test_prompt_initialization_with_valid_id
    # Create the test prompt files first
    create_test_prompt('test_prompt', 'Hello, World!', {})

    prompt = PromptManager::Prompt.new(id: 'test_prompt', context: [], directives_processor: PromptManager::DirectiveProcessor.new)
    assert_equal 'test_prompt', prompt.id
  end

  def test_prompt_to_s_method
    # Create the test prompt files first
    create_test_prompt('test_prompt', 'Hello, World!', {})

    prompt = PromptManager::Prompt.new(id: 'test_prompt', context: [], directives_processor: PromptManager::DirectiveProcessor.new)
    # Build removes comments and directives, but keeps __END__ etc.
    # EDIT: Now removes __END__ and subsequent lines.
    expected = "Hello, World!"
    assert_equal expected, prompt.to_s
  end

  def test_prompt_saves_to_storage
    new_prompt_id         = 'new_prompt'
    new_prompt_text       = "How are you, [NAME]?"
    new_prompt_parameters = { 'name' => 'Rubyist' }

    PromptManager::Prompt.create(
      id:         new_prompt_id,
      text:       new_prompt_text,
      parameters: new_prompt_parameters
    )

    prompt_from_storage = PromptManager::Prompt.get(id: 'new_prompt')

    assert_equal new_prompt_text,       prompt_from_storage[:text]
    assert_equal new_prompt_parameters, prompt_from_storage[:parameters]
  end

  def test_prompt_deletes_from_storage
    # Create a prompt first
    test_id = 'delete_test_prompt'
    create_test_prompt(test_id, 'Hello, I will be deleted', {})

    prompt = PromptManager::Prompt.find(id: test_id)
    assert_equal test_id, prompt.id # Verify it exists

    prompt.delete

    assert_raises(ArgumentError) do
      PromptManager::Prompt.get(id: test_id) # Should raise error when prompt not found
    end
  end

  def test_prompt_searches_storage
    # Create multiple prompts to search through
    create_test_prompt('search_test_1', 'Hello, this is the first test prompt', {})
    create_test_prompt('search_test_2', 'Goodbye, this is the second test prompt', {})
    create_test_prompt('search_test_3', 'Hello again, this is the third test prompt', {})

    # Search for a term that should match two prompts
    search_results = PromptManager::Prompt.search('Hello')

    refute_empty search_results
    assert_includes search_results, 'search_test_1'
    assert_includes search_results, 'search_test_3'
    refute_includes search_results, 'search_test_2'
  end

  private

  # Helper method to create test prompt files
  def create_test_prompt(id, text, parameters)
    # Get file extensions from the adapter
    prompt_ext = PromptManager::Storage::FileSystemAdapter.prompt_extension
    params_ext = PromptManager::Storage::FileSystemAdapter.params_extension

    # Create the prompt and parameter files in the test directory
    prompt_path = @test_prompts_dir.join("#{id}#{prompt_ext}")
    params_path = @test_prompts_dir.join("#{id}#{params_ext}")

    File.write(prompt_path, text)
    File.write(params_path, parameters.to_json)
  end
end

__END__
