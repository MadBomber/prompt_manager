# lib/prompt_manager/directive_processor.rb

# This is an example of a directive processor class.
# It only supports the //include directive which is also
# aliased as //import.

module PromptManager
  class DirectiveProcessor
    EXCLUDED_METHODS = %w[ run initialize ]

    def initialize
      @prefix_size    = PromptManager::Prompt::DIRECTIVE_SIGNAL.size
      @included_files = []
    end

    def run(directives)
      return {} if directives.nil? || directives.empty?
      directives.each do |key, _|
        sans_prefix = key[@prefix_size..]
        args        = sans_prefix.split(' ')
        method_name = args.shift

        if EXCLUDED_METHODS.include?(method_name)
          directives[key] = "Error: #{method_name} is not a valid directive: #{key}"
        elsif respond_to?(method_name)
          directives[key] =  send(method_name, *args)
        else
          directives[key] = "Error: Unknown directive '#{key}'"
        end
      end
      directives
    end

    def include(file_path)
      if  File.exist?(file_path) &&
          File.readable?(file_path) &&
          !@included_files.include?(file_path)
        content = File.read(file_path)
        @included_files << file_path
        content
      else
        "Error: File '#{file_path}' not accessible"
      end
    end
    alias_method :import, :include
  end
end
