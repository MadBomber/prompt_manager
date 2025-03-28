# lib/prompt_manager/directive_processor.rb

module PromptManager
  class DirectiveProcessor
    def initialize(directives)
      @directives = directives
    end

    def magic
      return {} if @directives.nil? || @directives.empty?
      @directives.transform_values! { "xyzzy" }
    end
  end
end
