# prompt_manager/lib/prompt_manager/storage/active_record_adapter.rb

require 'active_record'

# TODO: Will need a database.yml file
#       will need to know the column names that coorespond
#       with the things that the Prompt class wants.

class PromptManager::Storage::ActiveRecordAdapter
  attr_reader :model_class

  def initialize(model_class)
    @model_class = model_class
  end


  def prompt_text(prompt_id)
    prompt = find_prompt(prompt_id)
    prompt.text
  end


  def parameter_values(prompt_id)
    prompt = find_prompt(prompt_id)
    JSON.parse(prompt.params, symbolize_names: true)
  end


  def save(prompt_id, prompt_text, parameter_values)
    prompt        = model_class.find_or_initialize_by(id: prompt_id)
    prompt.text   = prompt_text
    prompt.params = parameter_values.to_json
    prompt.save!
  end


  def delete(prompt_id)
    prompt = find_prompt(prompt_id)
    prompt.destroy
  end


  def search(for_what)
    # TODO: search through all prompts. Return an Array of
    #       prompt_id where the text of the prompt contains
    #       for_what is being searched.

    []
  end


  class << self
    def config
      # TODO: establish a connection to the database
      #       maybe define the prompts table and its
      #       columns of interest.
    end
  end

  ###############################################
  private

  def find_prompt(prompt_id)
    model_class.find_by(id: prompt_id) || raise('Prompt not found')
  end
end