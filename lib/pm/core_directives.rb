# frozen_string_literal: true

require 'pathname'

module PM
  # PM's built-in directives: include, insert (alias read).
  class CoreDirectives < Directive
    desc "Include and render another prompt file"
    def include(ctx, path)
      unless ctx.directory
        raise IncludeContextError, 'include requires a file context (use PM.parse with a file path)'
      end

      full_path = File.expand_path(path, ctx.directory)
      check_include_allowed!(ctx, full_path)

      child  = PM.parse(Pathname.new(full_path)) # Pathname: always read as a file, whatever the extension
      result = child.render_with(ctx.params, ctx.included, ctx.depth + 1)

      ctx.metadata.includes << {
        path:     full_path,
        depth:    ctx.depth + 1,
        metadata: child.metadata.to_h.reject { |key, _| key == :includes },
        includes: child.metadata.includes
      }

      result
    end

    desc "Insert a file's raw content verbatim (no ERB, no shell expansion)"
    def insert(ctx, path)
      full_path = File.expand_path(path, ctx.directory)
      raise FileNotFoundError, "insert: file not found: #{full_path}" unless File.file?(full_path)

      File.read(full_path, encoding: Encoding::UTF_8)
    end
    alias_method :read, :insert

    private

    def check_include_allowed!(ctx, full_path)
      if ctx.included.include?(full_path)
        raise CircularIncludeError, "Circular include detected: #{full_path}"
      end

      max = PM.config.max_include_depth
      return unless max && ctx.depth + 1 > max

      raise IncludeDepthError, "Include depth exceeds #{max} (PM.config.max_include_depth): #{full_path}"
    end
  end
end
