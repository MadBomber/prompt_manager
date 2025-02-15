# prompt_manager/test/prompt_manager/storage/file_system_adapter_test.rb

require 'test_helper'

require 'prompt_manager/storage/file_system_adapter'

# Lets create a shortcut ...
FSA = PromptManager::Storage::FileSystemAdapter


class FileSystemAdapterTest < Minitest::Test
  def setup
    @prompts_dir  = $PROMPTS_DIR   # defined in test_helper
    @prompt_id    = 'test_prompt'

    # An instance pf a stprage adapter class
    @adapter  = FSA.config do |o|
                  o.prompts_dir = $PROMPTS_DIR   
                end.new
    directive_example_filename = 'directive_example' + PromptManager::Storage::FileSystemAdapter::PROMPT_EXTENSION
    directive_example_file     = File.join(@prompts_dir, directive_example_filename)
    File.delete(directive_example_file) if File.exist?(directive_example_file)
  end


  def teardown
    # what should be torn down?
  end

  ############################################
  def test_config
    assert_equal FSA, PromptManager::Storage::FileSystemAdapter
    
    assert FSA.respond_to? :config

    # debug_me{[
    #   'FSA::search_proc', #=> nil
    #   'FSA::SEARCH_PROC'  #=> nil
    # ]}

    assert_equal FSA.prompts_dir,       $PROMPTS_DIR
    # SMELL: assert_equal FSA.search_proc,       FSA::SEARCH_PROC
    assert_equal FSA.prompt_extension,  FSA::PROMPT_EXTENSION
    assert_equal FSA.params_extension,  FSA::PARAMS_EXTENSION
  end


  def test_config_without_a_block
    assert_raises ArgumentError do
      FSA.config
    end
  end


  ############################################
  def test_list
    assert FSA.respond_to? :list
    assert @adapter.respond_to? :list

    result = @adapter.list

    assert result.is_a?(Array)
    assert result.first.is_a?(String)
    assert result.include?('todo')
    assert result.include?('toy/8-ball')

    class_result = FSA.list

    assert class_result.is_a?(Array)
    assert class_result.first.is_a?(String)
    assert class_result.include?('todo')
    assert class_result.include?('toy/8-ball')
  end


  ############################################
  def test_path
    assert FSA.respond_to? :path
    assert @adapter.respond_to? :path

    class_result  = FSA.path('todo')
    result        = @adapter.path('todo')

    assert_equal class_result, result

    assert_equal result.parent, @prompts_dir
    assert_equal result.extname.to_s, FSA.prompt_extension
    assert_equal result.basename.to_s.split('.').first, 'todo'
  end


  ############################################
  def test_get
    # Setup
    expected_text   = 'This is a prompt.'
    expected_params = {
      '[SIZE]'  => 20, 
      '[COLOR]' => 'blue'
    }

    prompt_path = @prompts_dir + (@prompt_id + FSA.prompt_extension)
    params_path = @prompts_dir + (@prompt_id + FSA.params_extension)

    prompt_path.write(expected_text)
    params_path.write(expected_params.to_json)

    # Exercise
    result = @adapter.get(id: @prompt_id)

    # Verify
    assert_equal expected_text, result[:text]
    assert_equal expected_params, result[:parameters]
  end


  ############################################
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


  ############################################
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


  ############################################
  def test_search_proc
    search_term = "MadBomber"
    saved_search_proc = @adapter.class.search_proc

    # search_proc is a way to use command line tools like
    # grep, rg, aq, ack, etc or anything else that makes
    # sense that will return a list of prompt IDs.
    # In the case of the FileSystemAdapter the ID is
    # the basename of the file snns its extension.
    @adapter.class.search_proc = ->(q) { ["hello #{q}"] }
    
    expected  = ["hello madbomber"] # NOTE: query term is all lowercase
    results   = @adapter.search(search_term)

    assert_equal expected, results

    @adapter.class.search_proc = saved_search_proc
  end


  ############################################
  def test_search
    # Setup
    search_term         = 'hello'
    included_text       = 'this contains hello'
    also_included_text  = "Hello Dolly!\nWell HELLO Freddy"  # NOTE: case difference to search term
    directive_example_text = 'directive example with hello'
    excluded_text          = 'this does not'

    file_ext = PromptManager::Storage::FileSystemAdapter::PROMPT_EXTENSION

    included_filename = 'included' + file_ext
    included_file     = File.join(@prompts_dir, included_filename)

    also_included_filename = 'also_included' + file_ext
    also_included_file     = File.join(@prompts_dir, also_included_filename)

    excluded_filename = 'excluded' + file_ext
    directive_example_filename = 'directive_example' + file_ext
    directive_example_file     = File.join(@prompts_dir, directive_example_filename)
    excluded_file              = File.join(@prompts_dir, excluded_filename)

    File.write(included_file,       included_text)
    File.write(directive_example_file, directive_example_text)
    File.write(excluded_file,          excluded_text)
    File.write(also_included_file,  also_included_text)

    expected = ["also_included", "directive_example", "included"]

    # Exercise
    results = @adapter.search(search_term)

    # Verify
    assert_equal results, expected
    refute_includes results, 'excluded'
  
    # Clean up
    File.delete(included_file)
    File.delete(excluded_file)
    File.delete(also_included_file)
  end

  # Add more tests for exceptional cases and edge conditions
end

