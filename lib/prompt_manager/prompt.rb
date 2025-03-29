# prompt_manager/lib/prompt_manager/prompt.rb

=begin
  This class is responsible for managing prompts which can be utilized by
  generative AI processes. This includes creation, retrieval, storage
  management, as well as building prompts with replacement of parameterized
  values and comment removal. It communicates with a storage system through a
  storage adapter.

  NOTE: PromptManager::Prompt relies on a configured storage adapter (such as
  FileSystemAdapter or ActiveRecordAdapter) to persist and retrieve prompt text
  and parameters.

  Directives are collected into a Hash where each key is the original directive
  line (String). The value is initially an empty String, intended to be
  populated with the directive's response later.

  Directives are collected from the prompt after parameter substitution has occurred. This means that directives within a
  prompt can be dynamic.

  PromptManager does not execute directives. They
  are made available to be passed on to downstream
  processes such as the example PrompManager::DirectiveProcessor
  which implements the //include directive.

=end



require_relative "directive_processor"

class PromptManager::Prompt
  COMMENT_SIGNAL          = '#'   # lines beginning with this are a comment
  DIRECTIVE_SIGNAL        = '//'  # Like the old IBM JCL
  DEFAULT_PARAMETER_REGEX = /(\[[A-Z _|]+\])/
  # @storage_adapter        = nil
  @parameter_regex        = DEFAULT_PARAMETER_REGEX

  # Public class methods
  class << self
    attr_accessor :storage_adapter, :parameter_regex

    alias_method :get, :new

    def create(id:, text: "", parameters: {})
      storage_adapter.save(
        id:         id,
        text:       text,
        parameters: parameters
      )

      new(id: id)
    end

    def find(id)
      new(id: id)
    end

    def destroy(id)
      prompt = find(id)
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

  attr_accessor :id,          # String name for the prompt
                :text,        # String, full text of the prompt
                :parameters,  # Hash, Key and Value are Strings


  def initialize(
      id:       nil,    # A String name for the prompt
      context:  [],     # TODO: Array of Strings or Pathname?
      directives_processor: PromptManager::DirectiveProcessor.new
    )

    @id  = id
    @directives_processor = directives_processor

    validate_arguments(@id)

    @record         = db.get(id: id)
    @text           = @record[:text]        || ""
    @parameters     = @record[:parameters]  || {}
    @directives     = {}
  end

  def validate_arguments(prompt_id, prompts_db=db)
    raise ArgumentError, 'id cannot be blank'           if prompt_id.nil? || prompt_id.strip.empty?
    raise(ArgumentError, 'storage_adapter is not set')  if prompts_db.nil?
  end

  def to_s
    processed_text = remove_comments
    processed_text = substitute_values(processed_text, @parameters)
    process_directives(processed_text)
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
    lines = @text.split("\n")
    end_index = lines.index("__END__") || lines.size
    lines[0...end_index].reject { |line| line.strip.start_with?(COMMENT_SIGNAL) }.join("\n")
  end

  def substitute_values(input_text, values_hash)
    if values_hash.is_a?(Hash) && !values_hash.empty?
      values_hash.each do |key, value|
        input_text = input_text.gsub(key, value)
      end
    end
    input_text
  end

  def process_directives(input_text)
    directive_lines = input_text.split("\n").select { |line| line.strip.start_with?(DIRECTIVE_SIGNAL) }
    @directives = directive_lines.each_with_object({}) { |line, hash| hash[line.strip] = "" }
    @directives = @directives_processor.run(@directives)
    substitute_values(input_text, @directives)
  end
end
