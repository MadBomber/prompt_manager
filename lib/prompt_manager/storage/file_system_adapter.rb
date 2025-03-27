# prompt_manager/lib/prompt_manager/storage/file_system_adapter.rb

# Use the local (or remote) file system as a place to
# store and access prompts.
#
# Adds two additional methods to the Prompt class:
#   list - returns Array of prompt IDs
#   path - returns a Pathname object to the prompt's text file
#   path(prompt_id) - same as path on the prompt instance
#
# Allows sub-directories of the prompts_dir to be
# used like categories. For example the prompt_id "toy/magic"
# is found in the `magic.txt` file inside the `toy` sub-directory
# of the prompts_dir.
#
# There can be many layers of categories (sub-directories)

require 'json'      # basic serialization of parameters
require 'pathname'

class PromptManager::Storage::FileSystemAdapter
  # Placeholder for search proc
  SEARCH_PROC       = nil
  # File extension for parameters
  PARAMS_EXTENSION  = '.json'.freeze
  # File extension for prompts
  PROMPT_EXTENSION  = '.txt'.freeze
  # Regular expression for valid prompt IDs
  PROMPT_ID_FORMAT  = /^[a-zA-Z0-9\-\/_]+$/

  class << self
    # Accessors for configuration options
    attr_accessor :prompts_dir, :search_proc, 
                  :params_extension, :prompt_extension

    # Configure the adapter
    def config
      if block_given?
        yield self
        validate_configuration
      else
        raise ArgumentError, "No block given to config"
      end

      self
    end

    # Expansion methods on the Prompt class specific to
    # this storage adapter.

    # Ignore the incoming prompt_id
    def list(prompt_id = nil)
      new.list
    end

    def path(prompt_id)
      new.path(prompt_id)
    end

    #################################################
    private

    # Validate the configuration
    def validate_configuration
      validate_prompts_dir
      validate_search_proc
      validate_prompt_extension
      validate_params_extension
    end

    # Validate the prompts directory
    def validate_prompts_dir
      # This is a work around for a Ruby scope issue where the 
      # class getter/setter method is becoming confused with a 
      # local variable when anything other than plain 'ol get and 
      # set are used. This error is in both Ruby v3.2.2 and
      # v3.3.0-preview3.
      #
      prompts_dir_local = self.prompts_dir

      unless prompts_dir_local.is_a?(Pathname)
        prompts_dir_local = Pathname.new(prompts_dir_local) unless prompts_dir_local.nil?
      end

      prompts_dir_local = prompts_dir_local.expand_path

      raise(ArgumentError, "prompts_dir: #{prompts_dir_local}") unless prompts_dir_local.exist? && prompts_dir_local.directory?
      
      self.prompts_dir = prompts_dir_local
    end

    # Validate the search proc
    def validate_search_proc
      search_proc_local = self.search_proc

      if search_proc_local.nil?
        search_proc_local = SEARCH_PROC
      else
        raise(ArgumentError, "search_proc invalid; does not respond to call") unless search_proc_local.respond_to?(:call)
      end

      self.search_proc = search_proc_local
    end

    # Validate the prompt extension
    def validate_prompt_extension
      prompt_extension_local = self.prompt_extension

      if prompt_extension_local.nil?
        prompt_extension_local = PROMPT_EXTENSION
      else
        unless  prompt_extension_local.is_a?(String)    &&
                prompt_extension_local.start_with?('.')
          raise(ArgumentError, "Invalid prompt_extension: #{prompt_extension_local}")
        end
      end

      self.prompt_extension = prompt_extension_local
    end

    # Validate the params extension
    def validate_params_extension
      params_extension_local = self.params_extension

      if params_extension_local.nil?
        params_extension_local = PARAMS_EXTENSION
      else
        unless  params_extension_local.is_a?(String)    &&
                params_extension_local.start_with?('.')
          raise(ArgumentError, "Invalid params_extension: #{params_extension_local}")
        end
      end

      self.params_extension = params_extension_local
    end
  end

  ##################################################
  ###
  ##  Instance
  #

  # Accessors for instance variables
  def prompts_dir       = self.class.prompts_dir
  def search_proc       = self.class.search_proc
  def prompt_extension  = self.class.prompt_extension
  def params_extension  = self.class.params_extension

  # Initialize the adapter
  def initialize
    # NOTE: validate because main program may have made
    #       changes outside of the config block
    self.class.send(:validate_configuration) # send gets around private designations of a method
  end

  # Get a prompt by ID
  def get(id:)
    validate_id(id)
    verify_id(id)

    {
      id:         id,
      text:       prompt_text(id),
      parameters: parameter_values(id)
    }
  end

  # Retrieve prompt text by its id
  def prompt_text(prompt_id)
    read_file(file_path(prompt_id, prompt_extension))
  end

  # Retrieve parameter values by its id
  def parameter_values(prompt_id)
    params_path = file_path(prompt_id, params_extension)
    
    if params_path.exist?
      parms_content = read_file(params_path)
      deserialize(parms_content)
    else
      {}
    end
  end

  # Save prompt text and parameter values to corresponding files
  def save(
      id:, 
      text: "", 
      parameters: {}
    )
    validate_id(id)

    prompt_filepath = file_path(id, prompt_extension)
    params_filepath = file_path(id, params_extension)
    
    write_with_error_handling(prompt_filepath, text)
    write_with_error_handling(params_filepath, serialize(parameters))
  end

  # Delete prompt text and parameter values files
  def delete(id:)
    validate_id(id)

    prompt_filepath = file_path(id, prompt_extension)
    params_filepath = file_path(id, params_extension)
    
    delete_with_error_handling(prompt_filepath)
    delete_with_error_handling(params_filepath)
  end

  # Search for prompts
  def search(for_what)
    search_term = for_what.downcase

    if search_proc.is_a? Proc
      search_proc.call(search_term)
    else
      search_prompts(search_term)
    end
  end

  # Return an Array of prompt IDs
  def list(*)
    prompt_ids = []
    
    Pathname.glob(prompts_dir.join("**/*#{prompt_extension}")).each do |file_path|
      prompt_id = file_path.relative_path_from(prompts_dir).to_s.gsub(prompt_extension, '')
      prompt_ids << prompt_id
    end

    prompt_ids
  end

  # Returns a Pathname object for a prompt ID text file
  # However, it is possible that the file does not exist.
  def path(id)
    validate_id(id)
    file_path(id, prompt_extension) 
  end

  ##########################################
  private

  # Validate that the ID contains good characters.
  def validate_id(id)
    raise ArgumentError, "Invalid ID format id: #{id}" unless id =~ PROMPT_ID_FORMAT
  end

  # Verify that the ID exists
  def verify_id(id)
    unless file_path(id, prompt_extension).exist?
      raise ArgumentError, "Invalid prompt_id: #{id}"
    end
  end

  # Write to a file with error handling
  def write_with_error_handling(file_path, content)
    begin
      file_path.write content
      true
    rescue IOError => e
      raise "Failed to write to file: #{e.message}"
    end
  end

  # Delete a file with error handling
  def delete_with_error_handling(file_path)
    begin
      file_path.delete
      true
    rescue IOError => e
      raise "Failed to delete file: #{e.message}"
    end
  end

  # Get the file path for a prompt ID and extension
  def file_path(id, extension)
    prompts_dir + "#{id}#{extension}"
  end

  # Read a file
  def read_file(full_path)
    raise IOError, 'File does not exist' unless File.exist?(full_path)
    File.read(full_path)
  end

  # Search for prompts
  def search_prompts(search_term)
    prompt_ids = []
    
    Pathname.glob(prompts_dir.join("**/*#{prompt_extension}")).each do |prompt_path|
      if prompt_path.read.downcase.include?(search_term)
        prompt_id = prompt_path.relative_path_from(prompts_dir).to_s.gsub(prompt_extension, '')    
        prompt_ids << prompt_id
      end
    end

    prompt_ids
  end

  # Serialize data to JSON
  def serialize(data)
    data.to_json
  end

  # Deserialize JSON data
  def deserialize(data)
    JSON.parse(data)
  end
end
