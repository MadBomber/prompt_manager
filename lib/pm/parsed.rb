# frozen_string_literal: true

require 'set'
require 'ostruct'
require 'erb'

module PM
  # Render context passed to registered directives.
  RenderContext = Struct.new(:directory, :params, :included, :depth, :metadata, keyword_init: true)

  Parsed = Struct.new(:metadata, :content, keyword_init: true) do
    def [](key)
      metadata[key]
    end

    # Returns the prompt content with ERB tags expanded.
    # Registered directives are available as methods in the ERB binding.
    # Raises if any required parameters (default: null) are not provided.
    # When metadata has erb: false, returns content without ERB processing.
    def to_s(values = {})
      render_with(values, Set.new, 0)
    end

    def render_with(values, included, depth)
      metadata.includes = []
      return content unless metadata.erb?

      defaults = metadata.parameters || {}
      params = defaults.merge(values.transform_keys(&:to_s))

      missing = params.select { |_, v| v.nil? }.keys
      unless missing.empty?
        raise ArgumentError, "Missing required parameters: #{missing.join(', ')}"
      end

      if metadata.directory && metadata.name
        included.add(File.join(metadata.directory, metadata.name))
      end

      context = OpenStruct.new(params)

      render_ctx = PM::RenderContext.new(
        directory: metadata.directory,
        params:    params,
        included:  included,
        depth:     depth,
        metadata:  metadata
      )

      PM.directives.each do |name, block|
        context.define_singleton_method(name) do |*args|
          block.call(render_ctx, *args)
        end
      end

      ERB.new(content).result(context.instance_eval { binding })
    end
  end
end
