# frozen_string_literal: true

require 'yaml'

module PM
  # Passed as the first argument to every directive.
  #
  #   directory -- directory of the file being rendered (nil for string prompts)
  #   params    -- merged parameter values (String keys)
  #   included  -- Set of ancestor file paths, used for circular-include detection
  #   depth     -- include nesting depth (0 for the top-level prompt)
  #   metadata  -- the current file's PM::Metadata
  RenderContext = Data.define(:directory, :params, :included, :depth, :metadata) do
    def initialize(directory: nil, params: {}, included: Set.new, depth: 0, metadata: nil)
      super(directory: directory, params: params, included: included, depth: depth, metadata: metadata)
    end
  end

  # Metadata keys PM adds itself when parsing a file, or fills in while rendering.
  # They are left out of #to_markdown so a prompt round-trips cleanly.
  DERIVED_METADATA_KEYS = %i[directory name created_at modified_at includes].freeze

  # The result of PM.parse: front matter plus content with shell references
  # already expanded. Call #to_s to render the ERB.
  Parsed = Data.define(:metadata, :content) do
    def [](key) = metadata[key]

    def key?(key) = metadata.key?(key)

    # The `parameters` mapping from the front matter ({} when absent).
    def parameters = metadata.parameters || {}

    # Renders the content with ERB. Registered directives and parameters are
    # available as bare identifiers. Raises PM::MissingParameterError (an
    # ArgumentError) if a `null`-default parameter is not supplied.
    # With `erb: false` the content is returned untouched.
    def to_s(values = {})
      Renderer.new(self).render(values)
    end

    # Rendering entry point used by the `include` directive, which must pass
    # the active include chain and depth through.
    def render_with(values, included, depth)
      Renderer.new(self).render(values, included: included, depth: depth)
    end

    def to_h
      { metadata: metadata.to_h, content: content }
    end

    # The prompt as a markdown file again: YAML front matter followed by the
    # content. Keys PM derived from the file system (directory, name, timestamps)
    # and the `includes` tree are omitted. `shell` and `erb` are always written,
    # since their values were resolved against the global config at parse time.
    # Content is the parsed content, so shell references have already been expanded.
    def to_markdown
      authored = metadata.to_h.reject { |key, _| DERIVED_METADATA_KEYS.include?(key) }
      return content if authored.empty?

      yaml = YAML.dump(authored.transform_keys(&:to_s)).delete_prefix("---\n")
      "---\n#{yaml}---\n#{content}"
    end
  end
end
