# prompt_manager/lib/prompt_manager/prompt.rb

# TODO: Consider an ActiveModel ??

class PromptManager::Prompt
  PARAMETER_REGEX   = /\[([A-Z _]+)\]/.freeze
  # KEYWORD_REGEX   = /(\[[A-Z _|]+\])/ # NOTE: old from aip.rb
  @storage_adapter  = nil

  class << self
    attr_accessor :storage_adapter

    alias_method :get, :new

    def create(id:, text: "", parameters: {})
      storage_adapter.save(
        id:         id,
        text:       text,
        parameters: parameters
      )

      new(id: id)
    end

    def search(for_what)
      storage_adapter.search(for_what)
    end
  end
  
  attr_accessor :db, :id, :text, :parameters
  
  # FIXME:  Assumes that the prompt ID exists in storage,
  #         wo how do we create a new one?
  def initialize(
      id:       nil,  # A String name for the prompt
      context:  []    # FIXME: Array of Strings or Pathname?
    )

    raise ArgumentError, 'id cannot be blank' if id.nil? || id.strip.empty?
    
    @id  = id
    @db  = self.class.storage_adapter
    
    raise(ArgumentError, 'storage_adapter is not set') if db.nil?
    
    @record     = db.get(id: id)
    @text       = @record[:text]
    @parameters = @record[:parameters]

    @prompt     = interpolate_parameters
  end

  # Displays the prompt text after parameter interpolation.
  def to_s
    @prompt
  end

  def save
    db.save(
      id:         id, 
      text:       text, 
      parameters: parameters
    )    
  end


  def delete
    db.delete(id: id)  
  end


  ######################################
  private

  # Converts keys in the hash to lowercase symbols for easy parameter replacement.
  def symbolize_and_downcase_keys(hash)
    hash.map { |key, value| [key.to_s.downcase.to_sym, value] }.to_h
  end

  # Interpolate the parameters within the prompt.
  def interpolate_parameters
    text.gsub(PARAMETER_REGEX) do |match|
      param_name = match[1..-2].downcase
      parameters[param_name] || match
    end
  end

  
  # TODO: Implement and integrate ignore_after_end and apply the logic within initialize.
  
  # TODO: Implement and integrate extract_raw_prompt and apply the logic within initialize.
    
  # TODO: Implement a better error handling strategy for the storage methods (save, search, get).
  
  # TODO: Refactor class to support more explicit and semantic configuration and setup.
  
  # TODO: Consider adding a method to refresh the parameters and re-interpolate the prompt text.
  
  # TODO: Check the responsibility of the save method; should it deal with the parameters directly or leave it to storage?
    
  # TODO: Check overall consistency and readability of the code.
end

# Usage of the fixed class would change as follows:
# Assuming Storage is a defined class that manages storing and retrieving prompts.
# storage_instance = Storage.new(...)
# PromptManager::Prompt.storage_adapter = storage_instance

# prompt = PromptManager::Prompt.new(id: 'my_prompt_id')
# puts prompt.to_s
# Expected output would depend on the parameters stored with 'my_prompt_id'

__END__

def extract_raw_prompt
  array_of_strings = ignore_after_end
  print_header_comment(array_of_strings)

  array_of_strings.reject do |a_line|
                    a_line.chomp.strip.start_with?('#')
                  end
                  .join("\n")
end



def ignore_after_end
  array_of_strings  = configatron.prompt_path.readlines
                        .map{|a_line| a_line.chomp.strip}

  x = array_of_strings.index("__END__")

  unless x.nil?
    array_of_strings = array_of_strings[..x-1]
  end

  array_of_strings
end






# Usage example:
prompt_text     = "Hello, [NAME]! You are logged in as [ROLE]."
parameter_hash  = { 'NAME' => 'Alice', 'ROLE' => 'Admin' }
file_paths      = ['path/to/first_context', 'path/to/second_context']

prompt = Prompt.new(prompt_text, parameter_hash, *file_paths)
puts prompt.show
# Expected output: Hello, Alice! You are logged in as Admin.

