# prompt_manager/lib/prompt_manager/storage/active_record_adapter.rb

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

  private

  def find_prompt(prompt_id)
    model_class.find_by(id: prompt_id) || raise('Prompt not found')
  end
end