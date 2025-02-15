# prompt_manager/lib/prompt_manager/prompt.rb

# This class is responsible for managing prompts which can be utilized by
# generative AI processes. This includes creation, retrieval, storage management,
# as well as building prompts with replacement of parameterized values and 
# comment removal. It communicates with a storage system through a storage 
# adapter.
#
# Directives are collected into an Array where each entry is an Array
# of two elements. The first is the directive name as a String. The 
# second is a string of parameters used by the directive.
# 
# Directives are collected from the prompt after keyword
# substitution has occurred. This means that directives within a
# prompt can be dynamic.
#
# PromptManager does not execute directives. They
# are made available to be passed on to downstream
# processes.

class PromptManager::Prompt
  COMMENT_SIGNAL    = '#'   # lines beginning with this are a comment
  DIRECTIVE_SIGNAL  = '//'  # Like the old IBM JCL
  DEFAULT_PARAMETER_REGEX = /(\[[A-Z _|]+\])/
  @storage_adapter  = nil
  @parameter_regex  = DEFAULT_PARAMETER_REGEX

  # Public class methods
  class << self
    attr_accessor :storage_adapter, :parameter_regex

    alias_method :get, :new

    def create(id:, text: "", parameters: {})
      prompt = storage_adapter.save(
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
  
  # SMELL:  Does the db (aka storage adapter) really need
  #         to be accessible by the main program?
  attr_accessor :db, :id, :text, :parameters, :directives


  # Retrieve the specific prompt ID from the Storage system.
  def initialize(
      id:       nil,  # A String name for the prompt
      context:  []    # FIXME: Array of Strings or Pathname?
    )

    @id  = id
    @db  = self.class.storage_adapter
    
    validate_arguments(@id, @db)

    @record     = db.get(id: id)
    @text       = @record[:text]
    @parameters = @record[:parameters]
    @keywords   = []  # Array of String
    @directives = []  # Array of arrays. directive is first entry, rest are parameters

    update_keywords

    build
  end


  # Make sure the ID and DB are good-to-go
  def validate_arguments(prompt_id, prompts_db)
    raise ArgumentError, 'id cannot be blank'           if prompt_id.nil? || id.strip.empty?
    raise(ArgumentError, 'storage_adapter is not set')  if prompts_db.nil?
  end


  # Return tje prompt text suitable for passing to a
  # gen-AI process.
  def to_s
    build
  end
  alias_method :prompt, :to_s


  # Save the prompt to the Storage system
  def save
    db.save(
      id:         id, 
      text:       text, 
      parameters: parameters
    )    
  end


  # Delete this prompt from the Storage system
  def delete
    db.delete(id: id)  
  end


  # Build the @prompt String by replacing the keywords
  # with there parameterized values and removing all
  # the comments.
  #  
  def build
    @prompt = text.gsub(self.class.parameter_regex) do |match|
                param_name = match
                Array(parameters[param_name]).last || match
              end
              
    save_directives(@prompt)
    remove_comments
  end


  def keywords
    update_keywords
  end


  ######################################
  private

  def update_keywords
    @keywords = @text.scan(self.class.parameter_regex).flatten.uniq
    @keywords.each do |kw|
      @parameters[kw] = [] unless @parameters.has_key?(kw)
    end

    @keywords
  end


  def save_directives(keyword_substituted_string)
    @directives = []

    keyword_substituted_string.split("\n").each do |a_line|
      line = a_line.strip
      next unless line.start_with?(DIRECTIVE_SIGNAL)
      
      parts       = line.split(' ')
      directive   = parts.shift[DIRECTIVE_SIGNAL.length..] # drop the directive signal
      @directives << [directive, parts.join(' ')]
    end

    @directives
  end


  def remove_comments
    lines           = @prompt
                        .split("\n")
                        .reject{|a_line| 
                          a_line.strip.start_with?(COMMENT_SIGNAL)  ||
                          a_line.strip.start_with?(DIRECTIVE_SIGNAL)
                        }

    # Remove empty lines at the start of the prompt
    #
    lines = lines.drop_while(&:empty?)

    # Drop all the lines at __END__ and after
    #
    logical_end_inx = lines.index("__END__")

    @prompt = if logical_end_inx
                lines[0...logical_end_inx] # NOTE: ... means to not include last index
              else
                lines
              end.join("\n") 
  end
  

  # Handle storage errors
  # SMELL:  Just raise them or get out of their way and let the
  #         main program do tje job.
  def handle_storage_error(error)
    # Log the error message, notify, or take appropriate action
    log_error("Storage operation failed: #{error.message}")
    # Re-raise the error if necessary, or define recovery steps
    raise error
  end


  # Let the storage adapter instance take a crake at
  # these unknown methods.  Don't care what the args
  # are, just pass the prompt's ID.
  def method_missing(method_name, *args, &block)
    if db.respond_to?(method_name)
      db.send(method_name, id, &block)
    else
      super
    end
  end


  def respond_to_missing?(method_name, include_private = false)
    db.respond_to?(method_name, include_private) || super
  end


  # SMELL:  should this gem log errors or is that a function of
  #         main program?  I believe its the main program's job.
  def log_error(message)
    puts "ERROR: #{message}"
  end
end

