# frozen_string_literal: true

module PM
  # --- Directive registry ---

  @directives = {}

  # Registers one or more named directives available in ERB templates.
  # The block receives a RenderContext as its first argument,
  # followed by any arguments from the ERB call.
  # Multiple names register the same block under each name (aliases).
  # Raises RuntimeError if any name is already registered.
  def self.register(*names, &block)
    names.each do |name|
      name = name.to_sym
      if @directives.key?(name)
        raise "Directive already registered: #{name}"
      end
      @directives[name] = block
    end
  end

  # Returns the registered directives hash.
  def self.directives
    @directives
  end

  # Clears all directives and re-registers from PM::Directive subclasses.
  def self.reset_directives!
    @directives.clear
    PM::Directive.register_all
  end
end
