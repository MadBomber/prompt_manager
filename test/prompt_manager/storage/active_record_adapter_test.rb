# test/test_prompt_manager_storage_active_record_adapter.rb

require 'active_record'
require 'json'

require_relative '../../test_helper'

require 'prompt_manager/storage/active_record_adapter'


ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Schema.define do
  create_table :db_prompts do |t|
    t.string  :prompt_name
    t.string  :prompt_text
    t.text    :prompt_params
  end
end


class DbPrompt < ActiveRecord::Base
  serialize :prompt_params, JSON
end


class TestActiveRecordAdapter < Minitest::Test
  def setup
    # The @storage_adapter object used by the PromptManager::Prompt class
    # is an instance of the storage adapter class.
    @adapter = PromptManager::Storage::ActiveRecordAdapter.config do |config|
      config.model                  = DbPrompt
      config.prompt_id_column       = :prompt_name
      config.prompt_text_column     = :prompt_text
      config.parameters_column      = :prompt_params
    end.new
  end


  #################################################

  def test_config
    assert_equal DbPrompt,        @adapter.model
    assert_equal :prompt_name,    @adapter.prompt_id_column
    assert_equal :prompt_text,    @adapter.prompt_text_column
    assert_equal :prompt_params,  @adapter.parameters_column
  end


  def test_save
    @adapter.save(id: 'example_name', text: 'Example prompt', parameters: { size: 'large' })

    prompt_record = DbPrompt.find_by(prompt_name: 'example_name')
    
    assert prompt_record
    assert_equal 'Example prompt',    prompt_record.prompt_text
    assert_equal({'size' => 'large'}, prompt_record.prompt_params)
  end


  def test_get
    DbPrompt.create(
              prompt_name:    'example_name', 
              prompt_text:    'Example prompt', 
              prompt_params:  { size: 'large' }.to_json
            )

    # The result is a Hash having the three keys expected
    # by the PromptManager::Prompt class
    result = @adapter.get(id: 'example_name')

    assert_equal Hash,                  result.class
    assert_equal 'example_name',        result[:id]
    assert_equal 'Example prompt',      result[:text]
    assert_equal({ 'size' => 'large' }, result[:parameters])
  end


  def test_list
    DbPrompt.create(prompt_name: 'example_name_1', prompt_text: 'Example prompt 1')
    DbPrompt.create(prompt_name: 'example_name_2', prompt_text: 'Example prompt 2')

    ids = @adapter.list
    assert_includes ids, 'example_name_1'
    assert_includes ids, 'example_name_2'
  end


  def test_delete
    DbPrompt.find_or_initialize_by(
      prompt_name: 'delete_me', 
      prompt_text: 'Example prompt to be deleted'
    ).save

    assert @adapter.get(id: 'delete_me')

    @adapter.delete(id: 'delete_me')

    assert_raises ArgumentError do
      @adapter.get(id: 'delete_me')
    end
  end


  def test_search
    DbPrompt.create(prompt_name: 'example_name_1', prompt_text: 'Example prompt 1')
    DbPrompt.create(prompt_name: 'example_name_2', prompt_text: 'Another example 2')

    search_result = @adapter.search('Another')
    assert_includes search_result, 'example_name_2'
    refute_includes search_result, 'example_name_1'
  end

  # Add tests to cover missing method behavior and validation of configuration.
  
  # Add test for method_missing
  def test_method_missing_delegates_to_record
    # DbPrompt.create(prompt_name: 'example_name', prompt_text: 'Example prompt')
    # @adapter.get(id: 'example_name')
    
    assert_respond_to @adapter, :where  # Assuming `where` is the method missing
    # assert_equal 'Example prompt', @adapter.prompt_text
  end


  def test_respond_to_missing_handles_record_methods
    assert_respond_to @adapter, :find_by_prompt_name  # Assuming record will have a `find_by_prompt_name` method
  end


  def test_validate_configuration
    assert_raises(ArgumentError) do
      PromptManager::Storage::ActiveRecordAdapter.config do |config|
        config.model = nil
      end
    end
  end
end

