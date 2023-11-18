# prompt_manager/test/prompt_manager/storage/file_system_adapter_test.rb

require 'fakefs/safe'

require_relative '../../test_helper'
require_relative '../../../lib/prompt_manager/storage/file_system_adapter'

class FileSystemAdapterTest < Minitest::Test
  def setup
    FakeFS.activate!

    @prompt_id    = 'test_prompt'
    @prompts_dir  = './test_prompts'

    FileUtils.mkdir_p(@prompts_dir)

    @adapter      = PromptManager::Storage::FileSystemAdapter.new(
                      prompts_dir: @prompts_dir
                    )
  end


  def teardown
    FakeFS.deactivate!
  end


  ############################################
  def test_get
    # Setup
    expected_text = 'This is a prompt.'
    expected_params = {size: 20, color: 'blue'}
    File.write(File.join(@prompts_dir, @prompt_id + PromptManager::Storage::FileSystemAdapter::PROMPT_EXTENSION), expected_text)
    File.write(File.join(@prompts_dir, @prompt_id + PromptManager::Storage::FileSystemAdapter::PARAMS_EXTENSION), expected_params.to_json)

    # Exercise
    result = @adapter.get(id: @prompt_id)

    # Verify
    assert_equal expected_text, result[:text]
    assert_equal expected_params, result[:parameters]
  end


  def test_save
    # Setup
    text = 'New prompt text'
    parameters = {difficulty: 'hard', time: 30}

    # Exercise
    @adapter.save(id: @prompt_id, text: text, parameters: parameters)

    # Verify
    assert File.exist?(File.join(@prompts_dir, @prompt_id + PromptManager::Storage::FileSystemAdapter::PROMPT_EXTENSION))
    assert File.exist?(File.join(@prompts_dir, @prompt_id + PromptManager::Storage::FileSystemAdapter::PARAMS_EXTENSION))
    assert_equal text, File.read(File.join(@prompts_dir, @prompt_id + PromptManager::Storage::FileSystemAdapter::PROMPT_EXTENSION))
    assert_equal parameters, JSON.parse(File.read(File.join(@prompts_dir, @prompt_id + PromptManager::Storage::FileSystemAdapter::PARAMS_EXTENSION)), symbolize_names: true)
  end


  def test_delete
    # Setup
    # Creating the files to be deleted
    File.write(File.join(@prompts_dir, @prompt_id + PromptManager::Storage::FileSystemAdapter::PROMPT_EXTENSION), 'To be deleted')
    File.write(File.join(@prompts_dir, @prompt_id + PromptManager::Storage::FileSystemAdapter::PARAMS_EXTENSION), {to_be: 'deleted'}.to_json)

    # Exercise
    @adapter.delete(id: @prompt_id)

    # Verify
    refute File.exist?(File.join(@prompts_dir, @prompt_id + PromptManager::Storage::FileSystemAdapter::PROMPT_EXTENSION))
    refute File.exist?(File.join(@prompts_dir, @prompt_id + PromptManager::Storage::FileSystemAdapter::PARAMS_EXTENSION))
  end


  def test_search_proc
    search_term = "Mad"

    # search_proc is a way to use command line tools like
    # grep, rg, aq, ack, etc or anything else that makes
    # sense that will return a list of prompt IDs.
    # In the case of the FileSystemAdapter the ID is
    # the basename of the file snns its extension.
    @adapter.instance_variable_set(:@search_proc, ->(q) { ["#{q}Bomber"] })
    
    expected  = ["MadBomber"]
    results   = @adapter.search(search_term)

    assert_equal results, expected
  end



  def test_search
    # Setup
    search_term         = 'hello'
    included_text       = 'this contains hello'
    also_included_text  = "Hello Dolly!\nWell HELLO Freddy"  # NOTE: case difference to search term
    excluded_text       = 'this does not'

    file_ext = PromptManager::Storage::FileSystemAdapter::PROMPT_EXTENSION

    included_filename = 'included' + file_ext
    included_file     = File.join(@prompts_dir, included_filename)

    also_included_filename = 'also_included' + file_ext
    also_included_file     = File.join(@prompts_dir, also_included_filename)

    excluded_filename = 'excluded' + file_ext
    excluded_file     = File.join(@prompts_dir, excluded_filename)

    File.write(included_file,       included_text)
    File.write(excluded_file,       excluded_text)
    File.write(also_included_file,  also_included_text)

    expected = ["also_included", "included"]

    # Exercise
    results = @adapter.search(search_term)

    # Verify
    assert_equal results, expected
    refute_includes results, 'excluded'
  end

  # Add more tests for exceptional cases and edge conditions
end

