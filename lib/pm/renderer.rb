# frozen_string_literal: true

require 'erb'

module PM
  # Turns a Parsed prompt into its final string: merges parameters, checks the
  # required ones, builds the RenderContext, and evaluates ERB.
  #
  # `included` is the set of ancestor file paths (the active include chain).
  # It is copied, never mutated, so sibling includes do not see each other.
  class Renderer
    def initialize(parsed)
      @parsed   = parsed
      @metadata = parsed.metadata
    end

    def render(values = {}, included: Set.new, depth: 0)
      @metadata.includes = []
      return @parsed.content unless @metadata.erb?

      params  = merge_params(values)
      context = build_context(params, included, depth)
      scope   = RenderScope.new(params, PM.directives, context, strict: PM.config.strict_parameters?)

      ERB.new(@parsed.content).result(scope.erb_binding)
    end

    private

    def merge_params(values)
      defaults = (@metadata.parameters || {}).transform_keys(&:to_s)
      params   = defaults.merge(values.transform_keys(&:to_s))

      missing = params.select { |_, value| value.nil? }.keys
      raise MissingParameterError, "Missing required parameters: #{missing.join(', ')}" unless missing.empty?

      params
    end

    def build_context(params, included, depth)
      ancestors = included.dup
      ancestors << own_path if own_path

      RenderContext.new(
        directory: @metadata.directory,
        params:    params,
        included:  ancestors,
        depth:     depth,
        metadata:  @metadata
      )
    end

    def own_path
      return nil unless @metadata.directory && @metadata.name

      File.join(@metadata.directory, @metadata.name)
    end
  end
end
