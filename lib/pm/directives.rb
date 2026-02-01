# frozen_string_literal: true

module PM
  # --- Directive registry ---

  @directives = {}

  # Registers a named directive available in ERB templates.
  # The block receives a RenderContext as its first argument,
  # followed by any arguments from the ERB call.
  # Raises RuntimeError if the name is already registered.
  def self.register(name, &block)
    name = name.to_sym
    if @directives.key?(name)
      raise "Directive already registered: #{name}"
    end
    @directives[name] = block
  end

  # Returns the registered directives hash.
  def self.directives
    @directives
  end

  # Clears all directives and re-registers the built-ins.
  def self.reset_directives!
    @directives.clear
    register_builtins
  end

  # --- Built-in directives ---

  def self.register_builtins
    register(:include) do |ctx, path|
      unless ctx.directory
        raise 'include requires a file context (use PM.parse with a file path)'
      end
      full_path = File.expand_path(path, ctx.directory)
      if ctx.included.include?(full_path)
        raise "Circular include detected: #{full_path}"
      end
      child = PM.parse(full_path)
      result = child.render_with(ctx.params, ctx.included, ctx.depth + 1)

      ctx.metadata.includes << {
        path:     full_path,
        depth:    ctx.depth + 1,
        metadata: child.metadata.to_h.reject { |k, _| k == :includes },
        includes: child.metadata.includes
      }

      result
    end
  end
  private_class_method :register_builtins

  register_builtins
end
