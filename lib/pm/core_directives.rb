# frozen_string_literal: true

# lib/pm/core_directives.rb
#
# PM's built-in directives: include, insert/read.
# Defined as a PM::Directive subclass using the desc/alias DSL.

module PM
  class CoreDirectives < Directive
    desc "Include and render another prompt file"
    def include(ctx, path)
      unless ctx.directory
        raise 'include requires a file context (use PM.parse with a file path)'
      end

      full_path = File.expand_path(path, ctx.directory)

      if ctx.included.include?(full_path)
        raise "Circular include detected: #{full_path}"
      end

      child  = PM.parse(full_path)
      result = child.render_with(ctx.params, ctx.included, ctx.depth + 1)

      ctx.metadata.includes << {
        path:     full_path,
        depth:    ctx.depth + 1,
        metadata: child.metadata.to_h.reject { |k, _| k == :includes },
        includes: child.metadata.includes
      }

      result
    end

    desc "Insert a file's raw content verbatim (no ERB, no shell expansion)"
    def insert(ctx, path)
      full_path = if ctx&.directory
                    File.expand_path(path, ctx.directory)
                  else
                    File.expand_path(path)
                  end

      unless File.exist?(full_path)
        raise "insert: file not found: #{full_path}"
      end

      File.read(full_path)
    end
    alias_method :read, :insert
  end
end
