# frozen_string_literal: true

require 'date'
require 'pathname'
require 'yaml'

# PM (PromptManager) parses YAML front matter from markdown strings or files.
# Pipeline: strip HTML comments → extract metadata → shell expansion → ERB on demand (#to_s).
#
# Not thread-safe: PM.config and the directive registry are process-wide state.
# Configure and register directives at boot, then parse and render from any thread.
module PM
  # Both fences must be `---` on a line of their own; trailing blanks and a
  # CR (Windows line endings) are allowed after each.
  METADATA_REGEXP = /
    \A
    [[:space:]]*
    ---[[:blank:]\r]*\n
    (?<metadata>.*?)
    ^---[[:blank:]\r]*$\n?
    (?<content>.*)
    \z
  /mx

  HTML_COMMENT_REGEXP = /<!--.*?-->/m
  ENV_VAR_REGEXP      = /\$\{([A-Z_][A-Z0-9_]*)\}|\$([A-Z_][A-Z0-9_]*)/
  UTF8_BOM            = "\xEF\xBB\xBF".b.freeze
  COMMAND_START       = '$('

  # Front-matter keys that control the pipeline and must be true/false.
  FLAG_KEYS   = %w[shell erb].freeze
  TRUE_WORDS  = %w[true yes on].freeze
  FALSE_WORDS = %w[false no off].freeze

  def self.config
    @config ||= Configuration.new
  end

  def self.configure
    yield config
    config
  end

  # --- Parsing ---

  # Parses a source through the full pipeline.
  #
  # When source is a Pathname, responds to :to_path, is a String ending in
  # ".md", a Symbol, or a single word (e.g. "greeting"), it is treated as a
  # file path. Symbols and single-word strings become "name.md" basenames.
  # Relative paths are resolved against PM.config.prompts_dir, or against the
  # current directory when it is '' or nil. The file is
  # read and `directory`, `name`, `created_at`, `modified_at` are added to
  # the metadata.
  #
  # Otherwise source is parsed directly as a string (see .parse_string).
  #
  # Raises Errno::ENOENT when the file does not exist.
  def self.parse(source)
    source = "#{source}.md" if source.is_a?(Symbol) || single_word?(source)
    return parse_string(source) unless file_source?(source)

    path   = resolve_path(source)
    parsed = parse_file(path)
    stat   = File.stat(path)

    metadata = build_metadata(
      parsed.metadata.to_h.merge(
        directory:   File.dirname(path),
        name:        File.basename(path),
        created_at:  birthtime(stat),
        modified_at: stat.mtime
      )
    )
    Parsed.new(metadata: metadata, content: parsed.content)
  end

  # Parses a string, never treating it as a file name.
  #
  # Raises PM::MetadataError when the front matter is not a YAML mapping, or
  # when `shell`, `erb`, or `parameters` have values of the wrong type.
  # YAML syntax errors raise Psych::SyntaxError.
  def self.parse_string(string)
    parse_text(string)
  end

  # Strips HTML comments from a string.
  def self.strip_comments(string)
    string.gsub(HTML_COMMENT_REGEXP, '')
  end


  # Reads a file as UTF-8 whatever the locale, dropping a leading UTF-8
  # byte order mark. Converts to Encoding.default_internal when it is set,
  # as File.read does (Ruby's 'r:BOM|UTF-8' mode skips that conversion).
  def self.read_file(path)
    text = File.binread(path).delete_prefix(UTF8_BOM).force_encoding(Encoding::UTF_8)
    Encoding.default_internal ? text.encode(Encoding.default_internal) : text
  end

  # --- Internals ---

  # Parses text read from path (nil for a string prompt). YAML errors name
  # the path and count lines from the top of the text.
  def self.parse_text(string, path = nil)
    stripped = strip_comments(string)
    match    = stripped.match(METADATA_REGEXP)

    if match
      offset   = stripped[0...match.begin(:metadata)].count("\n")
      metadata = build_metadata(load_front_matter(match[:metadata], path, offset))
      content  = match[:content]
    else
      metadata = build_metadata({})
      content  = stripped
    end

    content = expand_shell(content, erb_safe: metadata.erb?) if metadata.shell?

    Parsed.new(metadata: metadata, content: content)
  end
  private_class_method :parse_text

  # Parses the file at path; a MetadataError names the file, as Psych does.
  def self.parse_file(path)
    parse_text(read_file(path), path)
  rescue MetadataError => e
    raise MetadataError, "(#{path}): #{e.message}"
  end
  private_class_method :parse_file

  def self.file_source?(source)
    source.respond_to?(:to_path) || (source.is_a?(String) && source.end_with?('.md'))
  end
  private_class_method :file_source?

  # True when source is a single word: no spaces, path separators, or extension.
  def self.single_word?(source)
    source.is_a?(String) && source.match?(/\A\w+\z/)
  end
  private_class_method :single_word?

  def self.resolve_path(source)
    raw = source.respond_to?(:to_path) ? source.to_path : source
    dir = config.prompts_dir
    File.expand_path(raw, dir.to_s.empty? ? nil : dir)
  end
  private_class_method :resolve_path

  # File creation time, falling back to ctime where the platform or
  # filesystem has no birthtime (several Linux filesystems, containers).
  def self.birthtime(stat)
    stat.birthtime
  rescue NotImplementedError, NoMethodError
    stat.ctime
  end
  private_class_method :birthtime

  def self.load_front_matter(yaml, path = nil, offset = 0)
    data = YAML.safe_load(("\n" * offset) + yaml, permitted_classes: [Date, Time], filename: path)
    return {} if data.nil?
    raise MetadataError, "Front matter must be a YAML mapping, got #{data.class}" unless data.is_a?(Hash)

    data
  end
  private_class_method :load_front_matter

  # Builds Metadata with `shell` and `erb` resolved against the global config
  # (the file wins unless the config is locked) and the `parameters` type checked.
  def self.build_metadata(hash)
    attrs = hash.transform_keys(&:to_s)

    FLAG_KEYS.each do |key|
      global = config.public_send(key)
      value  = attrs[key]
      attrs[key] = if config.locked? || value.nil?
                     coerce_flag("PM.config.#{key}", global)
                   else
                     coerce_flag(key, value)
                   end
    end

    params = attrs['parameters']
    unless params.nil? || params.is_a?(Hash)
      raise MetadataError, "parameters must be a mapping, got #{params.class}"
    end

    Metadata.new(attrs)
  end
  private_class_method :build_metadata

  def self.coerce_flag(key, value)
    return value if value.equal?(true) || value.equal?(false)

    word = value.to_s.strip.downcase
    return true  if TRUE_WORDS.include?(word)
    return false if FALSE_WORDS.include?(word)

    raise MetadataError, "#{key} must be true or false, got #{value.inspect}"
  end
  private_class_method :coerce_flag
end

require_relative 'pm/version'
require_relative 'pm/errors'
require_relative 'pm/configuration'
require_relative 'pm/metadata'
require_relative 'pm/render_scope'
require_relative 'pm/renderer'
require_relative 'pm/parsed'
require_relative 'pm/shell'
require_relative 'pm/directives'
require_relative 'pm/directive'
require_relative 'pm/core_directives'

# Register built-in directives from PM::CoreDirectives
PM::Directive.register_all
