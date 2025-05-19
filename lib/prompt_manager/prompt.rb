# prompt_manager/lib/prompt_manager/prompt.rb

require_relative "directive_processor"

class PromptManager::Prompt
  COMMENT_SIGNAL          = '#'   # lines beginning with this are a comment
  DIRECTIVE_SIGNAL        = '//'  # Like the old IBM JCL
  DEFAULT_PARAMETER_REGEX = /(\[[A-Z _|]+\])/
  @parameter_regex        = DEFAULT_PARAMETER_REGEX

  ##############################################
  ## Public class methods

  class << self
    attr_accessor :storage_adapter, :parameter_regex

    def get(id:)
      storage_adapter.get(id: id)  # Return the hash directly from storage
    end

    def create(id:, text: "", parameters: {})
      storage_adapter.save(
        id:         id,
        text:       text,
        parameters: parameters
      )

      ::PromptManager::Prompt.new(id: id, context: [], directives_processor: PromptManager::DirectiveProcessor.new)
    end

    def find(id:)
      ::PromptManager::Prompt.new(id: id, context: [], directives_processor: PromptManager::DirectiveProcessor.new)
    end

    def destroy(id:)
      prompt = find(id: id)
      prompt.delete
    end

    def search(for_what)
      storage_adapter.search(for_what)
    end

    def method_missing(method_name, *args, &block)
      if storage_adapter.respond_to?(method_name)
        storage_adapter.send(method_name, *args, &block)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      storage_adapter.respond_to?(method_name, include_private) || super
    end
  end

  ##############################################
  ## Public Instance Methods

  attr_accessor :id,           # String name for the prompt
                :text,         # String, full text of the prompt
                :parameters    # Hash, Key and Value are Strings


  def initialize(
      id:       nil,    # A String name for the prompt
      context:  [],     # TODO: Array of Strings or Pathname?
      directives_processor: PromptManager::DirectiveProcessor.new,
      external_binding:     binding,
      erb_flag:             false,    # replace $ENVAR and ${ENVAR} when true
      envar_flag:           false     # process ERB against the external_binding when true
    )

    @id  = id
    @directives_processor = directives_processor

    validate_arguments(@id)

    @record           = db.get(id: id)
    @text             = @record[:text]        || ""
    @parameters       = @record[:parameters]  || {}
    @directives       = {}
    @external_binding = external_binding
    @erb_flag         = erb_flag
    @envar_flag       = envar_flag
  end

  def validate_arguments(prompt_id, prompts_db=db)
    raise ArgumentError, 'id cannot be blank'           if prompt_id.nil? || prompt_id.strip.empty?
    raise(ArgumentError, 'storage_adapter is not set')  if prompts_db.nil?
  end

  def to_s
    processed_text = remove_comments
    processed_text = substitute_values(processed_text, @parameters)
    processed_text = substitute_env_vars(processed_text)
    processed_text = process_directives(processed_text)
    process_erb(processed_text)
  end

  def save
    db.save(
      id:         id,
      text:       text,       # Save the original text
      parameters: parameters
    )
  end

  def delete = db.delete(id: id)


  ######################################
  private

  def db = self.class.storage_adapter


  def remove_comments
    lines = @text.gsub(/<!--.*?-->/m, '').lines(chomp: true)
    markdown_block_depth = 0
    filtered_lines = []
    end_index = lines.index("__END__") || lines.size

    lines[0...end_index].each do |line|
      trimmed_line = line.strip

      if trimmed_line.start_with?('```')
        if trimmed_line == '```markdown'
          markdown_block_depth += 1
        elsif markdown_block_depth > 0
          markdown_block_depth -= 1
        end
      end

      if markdown_block_depth > 0 || !trimmed_line.start_with?(COMMENT_SIGNAL)
        filtered_lines << line
      end
    end

    filtered_lines.join("\n")
  end




  def substitute_values(input_text, values_hash)
    if values_hash.is_a?(Hash) && !values_hash.empty?
      values_hash.each do |key, value|
        input_text = input_text.gsub(key, value)
      end
    end
    input_text
  end

  def erb?      = @erb_flag
  def envar?    = @envar_flag

  def substitute_env_vars(input_text)
    return input_text unless envar?

    input_text.gsub(/\$(\w+)|\$\{(\w+)\}/) do |match|
      env_var = $1 || $2
      ENV[env_var] || match
    end
  end

  def process_directives(input_text)
    directive_lines = input_text.split("\n").select { |line| line.strip.start_with?(DIRECTIVE_SIGNAL) }
    @directives = directive_lines.each_with_object({}) { |line, hash| hash[line.strip] = "" }
    @directives = @directives_processor.run(@directives)
    substitute_values(input_text, @directives)
  end

  def process_erb(input_text)
    return input_text unless erb?

    ERB.new(input_text).result(@external_binding)
  end
end
