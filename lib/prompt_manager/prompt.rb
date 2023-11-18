# prompt_manager/lib/prompt_manager/prompt.rb

class PromptManager::Prompt
  @@storage_adapter = nil

  PARAMETER_REGEX   = /\[([A-Z _]+)\]/.freeze
  KEYWORD_REGEX     = /(\[[A-Z _|]+\])/ # NOTE: old from aip.rb

  attr_accessor :text, :parameters

  def initialize(
      id: # A String name for the prompt
    )

    raise ArgumentError, 'storage cannot be nil'      if storage.nil?
    raise ArgumentError, 'prompt_id cannot be blank'  if id.nil? || id.empty?

    @storage    = storage
    @id         = prompt_id
    @raw_text   = @storage.prompt_text(prompt_id)
    @parameters = @storage.parameter_values(prompt_id)
    @text       = interpolate_parameters
  end

  # TODO: ignore any line in @raw_text whose first non-white space
  #       character is "#" - ie a comment line.

  # TODO: ignore allines in @raw_text that come after a line
  #       equal to "__END__"



  # Displays the prompt text after parameter interpolation.
  def to_s
    @prompt_text
  end


  def save
    @storage.save(id, @raw_text, parameters)    
  end


  def search(for_what)
    @storage.search(for_what)
  end

  class << self
    alias_method :get, :new
  end

  ###############################################
  private

  # Converts keys in the hash to lowercase symbols for easy parameter replacement.
  def symbolize_and_downcase_keys(hash)
    hash.map { |key, value| [key.to_s.downcase.to_sym, value] }.to_h
  end

  # Interpolate the parameters within the prompt.
  def interpolate_parameters
    @raw_text.gsub(PARAMETER_REGEX) do |match|
      param_name = match[1..-2].downcase.to_sym
      @parameters[param_name] || match
    end
  end
end

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

