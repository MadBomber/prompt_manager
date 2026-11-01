# frozen_string_literal: true

module PM
  # The object whose binding an ERB template is evaluated in.
  #
  # A bare identifier in a template resolves here, in this order:
  #   1. a parameter of that name, when called with no arguments
  #   2. a registered directive of that name (called with the RenderContext first)
  #   3. nil -- or PM::UnknownParameterError when PM.config.strict_parameters is on
  #
  # So a parameter shadows a zero-argument directive call of the same name, and
  # a directive call with arguments is never confused with a parameter.
  class RenderScope
    def initialize(params, directives, context, strict: false)
      @params     = params
      @directives = directives
      @context    = context
      @strict     = strict
      shadow_object_methods
    end

    # The binding ERB renders in. A method rather than instance_eval so the
    # only locals visible to the template are ERB's own.
    def erb_binding = binding

    def method_missing(name, *args, &block)
      key = name.to_s

      if args.empty? && @params.key?(key)
        @params[key]
      elsif (directive = @directives[name])
        directive.call(@context, *args, &block)
      elsif @strict
        raise UnknownParameterError, "Unknown parameter or directive: #{name}"
      elsif args.empty?
        nil
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      @params.key?(name.to_s) || @directives.key?(name) || super
    end

    private

    # A parameter named like a public Object method (`hash`, `display`, ...)
    # would otherwise never reach method_missing.
    def shadow_object_methods
      @params.each_key do |key|
        sym = key.to_sym
        next if Metadata::PROTECTED_METHODS.include?(sym)
        next unless Object.public_method_defined?(sym)

        define_singleton_method(sym) { @params[key] }
      end
    end
  end
end
