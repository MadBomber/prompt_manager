# prompt_manager/lib/prompt_manager/storage/file_system_adapter.rb

require 'json'
require 'pathname'

class PromptManager::Storage::FileSystemAdapter
  PARAMS_EXTENSION = '.json'.freeze
  PROMPT_EXTENSION = '.txt'.freeze

  class << self
    attr_accessor :prompts_dir, :search_proc, 
                  :params_extension, :prompt_extension
  
    def config
      yield self
      debug_me('== after block =='){[
        :prompts_dir,
        :search_proc,
        :prompt_extension,
        :params_extension
      ]}
      validate_configuration
    end


    def list(...)
      new.list
    end

    #################################################
    private

    def validate_configuration
      validate_prompts_dir
      validate_search_proc
      validate_prompt_extension
      validate_params_extension
    end


    def validate_prompts_dir
      unless prompts_dir.is_a?(Pathname)
        prompts_dir = Pathname.new(prompts_dir) unless prompts_dir.nil?
      end

      prompts_dir = prompts_dir.expand_path

      raise(ArgumentError, "prompts_dir: #{prompts_dir}") unless prompts_dir.exist? && prompts_dir.directory?
    end


    def validate_search_proc
      unless search_proc.nil?
        raise(ArgumentError, "search_proc invalid; does not respond to call") unless search_proc.respond_to?(:call)
      end
    end


    def validate_prompt_extension
      if prompt_extension.nil?
        prompt_extension = PROMPT_EXTENSION
      else
        unless  prompt_extension.is_a?(String)    &&
                prompt_extension.start_with?('.')
          raise(ArgumentError, "Invalid prompt_extension: #{prompt_extension}")
        end
      end
    end


    def validate_params_extension
      if params_extension.nil?
        params_extension = PARAMS_EXTENSION
      else
        unless  params_extension.is_a?(String)    &&
                params_extension.start_with?('.')
          raise(ArgumentError, "Invalid params_extension: #{params_extension}")
        end
      end
    end
  end


  def prompts_dir       = self.class.prompts_dir
  def search_proc       = self.class.search_proc
  def prompt_extension  = self.class.prompt_extension
  def params_extension  = self.class.params_extension


  def initialize
    self.class.validate_configuration
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
    read_file(file_path(prompt_id, prompt_extension))
  end


  # Retrieve parameter values by its id
  def parameter_values(prompt_id)
    json_content = read_file(file_path(prompt_id, params_extension))
    deserialize(json_content)
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


  # Delete prompted text and parameter values files
  def delete(id:)
    validate_id(id)

    prompt_filepath = file_path(id, prompt_extension)
    params_filepath = file_path(id, params_extension)
    
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


  # Return an Array of prompt IDs
  def list(...)
    prompt_ids = []
    
    Pathname.glob(prompts_dir.join("**/*#{prompt_extension}")).each do |file_path|
      prompt_id = file_path.relative_path_from(prompts_dir).to_s.gsub(promt_extension, '')
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
    raise ArgumentError, 'Invalid ID format' unless id =~ /^[a-zA-Z0-9\-_]+$/
  end


  # Verify that the ID actually exists
  def verify_id(id)
    file_path(id, prompt_extension).exist?
  end


  def write_with_error_handling(file_path, content)
    begin
      file_path.write content
    rescue IOError => e
      raise "Failed to write to file: #{e.message}"
    end
  end


  # file_path (Pathname)
  def delete_with_error_handling(file_path)
    begin
      file_path.delete
    rescue IOError => e
      raise "Failed to delete file: #{e.message}"
    end
  end


  def file_path(id, extension)
    prompts_dir + "#{id}#{extension}"
  end


  def read_file(full_path)
    raise IOError, 'File does not exist' unless File.exist?(full_path)
    File.read(full_path)
  end


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


  # TODO: Should the serializer be generic?

  def serialize(data)
    data.to_json
  end


  def deserialize(data)
    JSON.parse(data)
  end
end

__END__

require 'debug_me'
include DebugMe

require 'amazing_print'
require 'pathname'

class MyClass
  PARAMS_EXTENSION = '.json'.freeze
  PROMPT_EXTENSION = '.txt'.freeze

  class << self
    attr_accessor :prompts_dir, :search_proc,
                  :params_extension, :prompt_extension

    def config(&block)
      if block_given?
        self.class_eval(&block) # yield self
      else
        puts "ERROR: No config block"
        exit(1)
      end

      debug_me('== after block =='){[
        :prompts_dir,
        :search_proc,
        :prompt_extension,
        :params_extension
      ]}

      validate_configuration
    end

    def list(...)
      new.list
    end


    private

    def validate_configuration
      debug_me("=== validate =="){[
        :prompts_dir,
        :search_proc,
        :prompt_extension,
        :params_extension
      ]}

      validate_prompts_dir        # ; rescue => e; puts "\n\nERROR: #{e.message}"
      validate_search_proc        # ; rescue => e; puts "\n\nERROR: #{e.message}"
      validate_prompt_extension   # ; rescue => e; puts "\n\nERROR: #{e.message}"
      validate_params_extension   # ; rescue => e; puts "\n\nERROR: #{e.message}"
    end

    def validate_prompts_dir
      prompts_dir_local = prompts_dir.dup

      debug_me("=== INSIDE tdv_validate_prompts_dir =="){[
        :prompts_dir,
        :prompts_dir_local,
        :search_proc,
        :prompt_extension,
        :params_extension
      ]}


      unless prompts_dir_local.is_a?(Pathname)
        prompts_dir_local = Pathname.new(prompts_dir_local) unless prompts_dir_local.nil?
      end

      prompts_dir_local = prompts_dir_local.expand_path

      raise(ArgumentError, "prompts_dir: #{prompts_dir_local}") unless prompts_dir_local.exist? && prompts_dir.directory?
    
      prompts_dir = prompts_dir_local

      debug_me{[
        :prompts_dir,
        :prompts_dir_local
      ]}
    end


    def validate_search_proc
      search_proc_local = search_proc.dup

      debug_me("=== INSIDE tdv_validate_search_proc =="){[
        :prompts_dir,
        :search_proc,
        :search_proc_local,
        :prompt_extension,
        :params_extension
      ]}


      unless search_proc_local.nil?
        raise(ArgumentError, "search_proc invalid; does not respond to call") unless search_proc_local.respond_to?(:call)
      end

      search_proc = search_proc_local
    end


    def validate_prompt_extension
      prompt_extension_local = prompt_extension.dup

      debug_me("=== INSIDE tdv_validate_search_proc =="){[
        :prompts_dir,
        :search_proc,
        :prompt_extension,
        :prompt_extension_local,
        :params_extension
      ]}


      if prompt_extension_local.nil?
        prompt_extension_local = PROMPT_EXTENSION
      else
        unless  prompt_extension_local.is_a?(String)    &&
                prompt_extension_local.start_with?('.')
          raise(ArgumentError, "Invalid prompt_extension: #{prompt_extension_local}")
        end
      end
      prompt_extension = prompt_extension_local
    end


    def validate_params_extension
      params_extension_local = params_extension.dup

      debug_me("=== INSIDE tdv_validate_search_proc =="){[
        :prompts_dir,
        :search_proc,
        :prompt_extension,
        :params_extension,
        :params_extension_local
      ]}


      if params_extension_local.nil?
        params_extension_local = PARAMS_EXTENSION
      else
        unless  params_extension_local.is_a?(String)    &&
                params_extension_local.start_with?('.')
          raise(ArgumentError, "Invalid params_extension: #{params_extension_local}")
        end
      end

      params_extension = params_extension_local
    end
  end


  ##########################################
  ###
  ##  Instance methods
  #

  # Instance-level getters that proxy to the class-level variables
  def prompts_dir       = self.class.prompts_dir
  def search_proc       = self.class.search_proc
  def prompt_extension  = self.class.prompt_extension
  def params_extension  = self.class.params_extension
  
  def initialize
    # TODO: What?
  end

  def list(...)
    ap prompts_dir.children
  end

  # Instance method `hello` without using `self.class` prefix
  def hello
    puts prompts_dir
    puts search_proc.call('winning lotto ticket') # Assuming `search_proc` is a Proc/Lambda object
  
    debug_me{[
      :prompt_extension,
      :params_extension
    ]}

  end
end

# Using the DSL for configuration
MyClass.config do |option|
  option.prompts_dir      = Pathname.new(ENV['HOME']) + '.prompts'
  option.search_proc      = -> (q) { "find #{q} yourself"; [] }
  option.prompt_extension = ".docx"
  option.params_extension = ".yml"
end

# Instantiate MyClass and call the `hello` method
i = MyClass.new
i.hello
i.list
puts "======"
MyClass.list



