# prompt_manager/lib/prompt_manager/storage/file_system_adapter.rb


require 'json'

class PromptManager::Storage::FileSystemAdapter
  PARAMS_EXTENSION = '.json'.freeze
  PROMPT_EXTENSION = '.txt'.freeze

  attr_reader :prompts_directory

  def initialize(prompts_directory = '.prompts')
    @prompts_directory = prompts_directory
  end


  # Retrieve prompt text by its id
  def prompt_text(prompt_id)
    read_file(file_path(prompt_id, PROMPT_EXTENSION))
  end


  # Retrieve parameter values by its id
  def parameter_values(prompt_id)
    json_content = read_file(file_path(prompt_id, PARAMS_EXTENSION))
    JSON.parse(json_content, symbolize_names: true)
  end


  # Save prompt text and parameter values to corresponding files
  def save(prompt_id, prompt_text, parameter_values)
    prompt_filepath = file_path(prompt_id, PROMPT_EXTENSION)
    params_filepath = file_path(prompt_id, PARAMS_EXTENSION)
    
    File.write(prompt_filepath, prompt_text)
    File.write(params_filepath, parameter_values.to_json)
  end


  # Delete prompted text and parameter values files
  def delete(prompt_id)
    prompt_filepath = file_path(prompt_id, PROMPT_EXTENSION)
    params_filepath = file_path(prompt_id, PARAMS_EXTENSION)
    
    FileUtils.rm_f(prompt_filepath)
    FileUtils.rm_f(params_filepath)
  end


  #################################################
  private

  # Build the file path based on the prompt id and extension
  def file_path(prompt_id, extension)
    File.join(@prompts_directory, "#{prompt_id}#{extension}")
  end

  # Read content from a given file path
  def read_file(full_path)
    raise IOError, 'File does not exist' unless File.exist?(full_path)
    File.read(full_path)
  end
end
