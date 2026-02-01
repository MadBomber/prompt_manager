# frozen_string_literal: true

require 'date'
require 'pathname'
require 'yaml'

# PM (PromptManager) parses YAML metadata from markdown strings or files.
# Processing pipeline: strip HTML comments → extract metadata → shell expansion → ERB on demand.
module PM
  METADATA_REGEXP = /
    \A
    [[:space:]]*
    ---
    (?<metadata>.*?)
    ---
    [[:blank:]]*$[\n\r]?
    (?<content>.*)
    \z
  /mx

  HTML_COMMENT_REGEXP = /<!--.*?-->/m
  ENV_VAR_REGEXP     = /\$\{([A-Z_][A-Z0-9_]*)\}|\$([A-Z_][A-Z0-9_]*)/
  COMMAND_START      = '$('

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield config
  end

  # --- Parsing ---

  # Parses a source through the full pipeline:
  # strip HTML comments → extract YAML metadata → shell expansion (when shell: true).
  #
  # When source is a Pathname, responds to :to_path, or is a String ending
  # in ".md", it is treated as a file path. The file is read and parsed,
  # and `directory`, `name`, `created_at`, `modified_at` are added to metadata.
  #
  # Otherwise source is parsed directly as a string.
  def self.parse(source)
    if file_source?(source)
      raw = source.respond_to?(:to_path) ? source.to_path : source
      unless config.prompts_dir.empty?
        raw = (Pathname.new(config.prompts_dir) + raw).to_s
      end
      path = File.expand_path(raw)
      parsed = parse_string(File.read(path))

      stat = File.stat(path)
      metadata = build_metadata(
        parsed.metadata.to_h.merge(
          directory:   File.dirname(path),
          name:        File.basename(path),
          created_at:  stat.birthtime,
          modified_at: stat.mtime
        )
      )
      Parsed.new(metadata: metadata, content: parsed.content)
    else
      parse_string(source)
    end
  end

  # Returns true when source should be treated as a file path.
  def self.file_source?(source)
    source.respond_to?(:to_path) || (source.is_a?(String) && source.end_with?('.md'))
  end
  private_class_method :file_source?

  # Parses a string through the full pipeline.
  def self.parse_string(string)
    stripped = strip_comments(string)
    match = stripped.match(METADATA_REGEXP)

    if match
      metadata = build_metadata(YAML.safe_load(match[:metadata], permitted_classes: [Date, Time]))
      content = match[:content]
    else
      metadata = build_metadata({})
      content = stripped
    end

    content = expand_shell(content) if metadata.shell?

    Parsed.new(metadata: metadata, content: content)
  end
  private_class_method :parse_string

  # Builds a Metadata object with defaults for shell and erb.
  def self.build_metadata(hash)
    defaults = { 'shell' => config.shell, 'erb' => config.erb }
    Metadata.new(defaults.merge(hash.transform_keys(&:to_s)))
  end
  private_class_method :build_metadata

  # Strips HTML comments from a string.
  def self.strip_comments(string)
    string.gsub(HTML_COMMENT_REGEXP, '')
  end
end

require_relative 'pm/configuration'
require_relative 'pm/version'
require_relative 'pm/metadata'
require_relative 'pm/parsed'
require_relative 'pm/directives'
require_relative 'pm/shell'
