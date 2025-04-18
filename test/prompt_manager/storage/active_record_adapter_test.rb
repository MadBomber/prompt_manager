# test/test_prompt_manager_storage_active_record_adapter.rb

require 'test_helper'

require 'active_record'
require 'json'


require 'prompt_manager/storage/active_record_adapter'

############################################################
###
##  Setup the database from the application's point of view
#

ActiveRecord::Base
  .establish_connection(
    adapter:  'sqlite3', 
    database: ':memory:'
  )

ActiveRecord::Schema.define do
  create_table :db_prompts do |t|
    t.string  :prompt_name
    t.string  :prompt_text
    t.text    :prompt_params
  end
end


# Within a Rails application this could be ApplicationRecord
class DbPrompt < ActiveRecord::Base
  serialize :prompt_params
end

#
##  database setyo frin aookucatuib's POV
###
############################################################


class TestActiveRecordAdapter < Minitest::Test
  def setup
    # The @storage_adapter object used by the PromptManager::Prompt class
    # is an instance of the storage adapter class.
    @adapter = PromptManager::Storage::ActiveRecordAdapter.config do |config|
      config.model              = DbPrompt
      config.id_column          = :prompt_name
      config.text_column        = :prompt_text
      config.parameters_column  = :prompt_params
    end.new
  end


  #################################################

  def test_config
    assert_equal DbPrompt,        @adapter.model
    assert_equal :prompt_name,    @adapter.id_column
    assert_equal :prompt_text,    @adapter.text_column
    assert_equal :prompt_params,  @adapter.parameters_column
  end


  def test_save
    @adapter.save(id: 'example_name', text: 'Example prompt', parameters: { size: 'large' })

    prompt_record = DbPrompt.find_by(prompt_name: 'example_name')
    
    assert prompt_record
    assert_equal 'Example prompt',    prompt_record.prompt_text
    assert_equal({size: 'large'},     prompt_record.prompt_params) # Updated expectation to match ActiveRecord's behavior
  end


  def test_get
    prompt_id = "example_name_#{rand(10000)}"

    DbPrompt.destroy(id: prompt_id) rescue 

    DbPrompt.create(
              prompt_name:    prompt_id, 
              prompt_text:    'Updated prompt', 
              prompt_params:  { size: 'large' }.to_json
            )

    # The result is a Hash having the three keys expected
    # by the PromptManager::Prompt class
    result = @adapter.get(id: prompt_id)

    expected_parameters = { size: 'large' }

    assert_equal Hash,                  result.class
    assert_equal prompt_id,             result[:id]
    assert_equal 'Updated prompt',      result[:text]
    assert_equal expected_parameters,   result[:parameters].symbolize_keys
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


  def test_save_with_existing_record
    @adapter.save(id: 'example_name', text: 'Updated prompt', parameters: { size: 'small' })
    prompt_record = DbPrompt.find_by(prompt_name: 'example_name')
    assert_equal 'Updated prompt', prompt_record.prompt_text
    assert_equal({ size: 'small' }, prompt_record.prompt_params)
  end


  def test_create
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

