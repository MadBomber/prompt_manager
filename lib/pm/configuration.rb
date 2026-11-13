# frozen_string_literal: true

module PM
  # Global settings. Reach it through PM.config or PM.configure.
  #
  #   prompts_dir        -- prepended to relative paths given to PM.parse ('' or nil = none)
  #   shell              -- default for shell expansion when a file does not say
  #   erb                -- default for ERB rendering when a file does not say
  #   locked             -- when true, per-file `shell:` / `erb:` cannot override the globals
  #   max_include_depth  -- deepest allowed `include` nesting (nil = unlimited)
  #   strict_parameters  -- when true, an unknown name in a template raises instead of rendering ""
  class Configuration
    attr_accessor :prompts_dir, :shell, :erb, :max_include_depth
    attr_writer   :locked, :strict_parameters

    DEFAULT_MAX_INCLUDE_DEPTH = 10

    def initialize
      reset!
    end

    def reset!
      @prompts_dir       = ''
      @shell             = true
      @erb               = true
      @locked            = false
      @max_include_depth = DEFAULT_MAX_INCLUDE_DEPTH
      @strict_parameters = false
      self
    end

    # Stop per-file front matter from overriding the global shell/erb settings.
    def lock!
      @locked = true
      self
    end

    def unlock!
      @locked = false
      self
    end

    def locked? = @locked

    def strict_parameters? = @strict_parameters
  end
end
