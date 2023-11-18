# prompt_manager/lib/prompt_manager/storage/file_system_adapter.rb


require 'json'

class PromptManager::Storage::FileSystemAdapter
  PARAMS_EXTENSION = '.json'.freeze
  PROMPT_EXTENSION = '.txt'.freeze

  attr_reader :prompts_dir

  def initialize(
      prompts_dir:  '.prompts',
      search_proc:  nil   # Example: ->(q) {`ag -l #{q}`}
    )

    # validate that prompts_dir exist and is in fact a directory.
    unless Dir.exist?(prompts_dir)
      raise "Directory #{prompts_dir} does not exist or is not a directory"
    end

    @prompts_dir  = prompts_dir
    @search_proc  = search_proc
  end


  def get(id:)
    validate_id(id)

    {
      id:         id,
      text:       prompt_text(id),
      parameters: parameter_values(id)
    }
  end


  # Retrieve prompt text by its id
  def prompt_text(prompt_id)
    read_file(file_path(prompt_id, PROMPT_EXTENSION))
  end


  # Retrieve parameter values by its id
  def parameter_values(prompt_id)
    json_content = read_file(file_path(prompt_id, PARAMS_EXTENSION))
    deserialize(json_content)
  end


  # Save prompt text and parameter values to corresponding files
  def save(
      id:, 
      text: "", 
      parameters: {}
    )
    validate_id(id)

    prompt_filepath = file_path(id, PROMPT_EXTENSION)
    params_filepath = file_path(id, PARAMS_EXTENSION)
    
    write_with_error_handling(prompt_filepath, text)
    write_with_error_handling(params_filepath, serialize(parameters))
  end


  # Delete prompted text and parameter values files
  def delete(id:)
    validate_id(id)

    prompt_filepath = file_path(id, PROMPT_EXTENSION)
    params_filepath = file_path(id, PARAMS_EXTENSION)
    
    delete_with_error_handling(prompt_filepath)
    delete_with_error_handling(params_filepath)
  end


  def search(for_what)
    if @search_proc
      @search_proc.call(for_what)
    else
      search_prompts(for_what)
    end
  end


  ##########################################
  private

  def validate_id(id)
    raise ArgumentError, 'Invalid ID format' unless id =~ /^[a-zA-Z0-9\-_]+$/
  end


  def write_with_error_handling(file_path, content)
    begin
      File.write(file_path, content)
    rescue IOError => e
      raise "Failed to write to file: #{e.message}"
    end
  end


  def delete_with_error_handling(file_path)
    begin
      FileUtils.rm_f(file_path)
    rescue IOError => e
      raise "Failed to delete file: #{e.message}"
    end
  end


  def file_path(id, extension)
    File.join(@prompts_dir, "#{id}#{extension}")
  end


  def read_file(full_path)
    raise IOError, 'File does not exist' unless File.exist?(full_path)
    File.read(full_path)
  end


  def search_prompts(search_term)
    query_term = search_term.downcase

    Dir.glob(File.join(@prompts_dir, "*#{PROMPT_EXTENSION}")).each_with_object([]) do |file_path, ids|
      File.open(file_path) do |file|
        file.each_line do |line|
          if line.downcase.include?(query_term)
            ids << File.basename(file_path, PROMPT_EXTENSION)
            next
          end
        end
      end
    end.uniq
  end


  def serialize(data)
    data.to_json
  end


  def deserialize(data)
    JSON.parse(data, symbolize_names: true)
  end
end
