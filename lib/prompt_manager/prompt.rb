# prompt_manager/lib/prompt_manager/prompt.rb

class PromptManager::Prompt
  PARAMETER_REGEX = /\[([A-Z]+)\]/.freeze

  def initialize(storage, prompt_id)
    raise ArgumentError, 'storage cannot be nil'      if storage.nil?
    raise ArgumentError, 'prompt_id cannot be blank'  if prompt_id.nil? || prompt_id.empty?

    @storage          = storage
    @prompt_id        = prompt_id
    @prompt_text      = @storage.prompt_text(prompt_id)
    @parameter_values = @storage.parameter_values(prompt_id)

    interpolate_parameters
  end


  # Displays the prompt text after parameter interpolation.
  def to_s
    @prompt_text
  end


  def save
    @storage.save(@prompt_id, @prompt_text, @prompt_values)    
  end

  private

  # Converts keys in the hash to lowercase symbols for easy parameter replacement.
  def symbolize_and_downcase_keys(hash)
    hash.map { |key, value| [key.to_s.downcase.to_sym, value] }.to_h
  end

  # Interpolate the parameters within the prompt.
  def interpolate_parameters
    @prompt_text.gsub!(PARAMETER_REGEX) do |match|
      param_name = match[1..-2].downcase.to_sym
      @parameter_values[param_name] || match
    end
  end
end

__END__

# Usage example:
prompt_text     = "Hello, [NAME]! You are logged in as [ROLE]."
parameter_hash  = { 'NAME' => 'Alice', 'ROLE' => 'Admin' }
file_paths      = ['path/to/first_context', 'path/to/second_context']

prompt = Prompt.new(prompt_text, parameter_hash, *file_paths)
puts prompt.show
# Expected output: Hello, Alice! You are logged in as Admin.

