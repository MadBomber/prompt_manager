# frozen_string_literal: true

module PM
  # --- Directive registry ---
  #
  # Two kinds of registration share one namespace:
  #   PM.register(:name) { |ctx, *args| ... }   -- block directives
  #   PM::Directive subclasses + register_all   -- class directives
  #
  # Rules:
  #   * PM.register raises DirectiveAlreadyRegisteredError if ANY requested name
  #     is taken, and registers nothing in that case (atomic).
  #   * register_all may re-register a name that a Directive subclass owns
  #     (so it is idempotent and a later subclass can override an earlier one),
  #     but raises if the name was claimed with PM.register.

  @directives       = {}
  @directive_owners = {} # name => the PM::Directive subclass that registered it

  # Registers one or more names for the same block. The block receives a
  # RenderContext first, then the arguments from the ERB call.
  def self.register(*names, &block)
    raise ArgumentError, 'PM.register requires a block' unless block

    syms  = names.map(&:to_sym)
    taken = syms.find { |name| @directives.key?(name) }
    raise DirectiveAlreadyRegisteredError, "Directive already registered: #{taken}" if taken

    syms.each { |name| @directives[name] = block }
    nil
  end

  # A frozen snapshot of the registry (name => block). Mutating it has no
  # effect on PM; use PM.register / PM.reset_directives!.
  def self.directives
    @directives.dup.freeze
  end

  def self.directive?(name)
    @directives.key?(name.to_sym)
  end

  # Clears every directive, then re-registers the PM::Directive subclasses.
  def self.reset_directives!
    @directives.clear
    @directive_owners.clear
    PM::Directive.register_all
    nil
  end

  # Used by PM::Directive.register_all. Not part of the public API.
  def self.register_from_class(klass, names, block)
    syms = names.map(&:to_sym)

    syms.each do |name|
      next unless @directives.key?(name)
      if @directive_owners[name].nil?
        raise DirectiveAlreadyRegisteredError,
              "Directive already registered with PM.register: #{name}"
      end

      @directives.delete(name) # owned by a Directive subclass: later registration wins
    end

    syms.each do |name|
      @directives[name]       = block
      @directive_owners[name] = klass
    end
    nil
  end
  private_class_method :register_from_class
end
