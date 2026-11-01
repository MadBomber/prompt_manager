# frozen_string_literal: true

module PM
  # Schemaless front-matter container with dot-notation access.
  #
  #   meta = PM::Metadata.new('title' => 'Hi', shell: true)
  #   meta.title      #=> "Hi"
  #   meta[:title]    #=> "Hi"
  #   meta['title']   #=> "Hi"
  #   meta.shell?     #=> true     (predicates exist only for true/false values)
  #   meta.missing    #=> nil
  #   meta.other = 1  # setter
  #   meta.to_h       #=> {title: "Hi", shell: true, other: 1}   (Symbol keys)
  #
  # Keys are stored as Symbols; `[]`, `[]=`, and `key?` accept Strings or Symbols.
  # A key whose name collides with a public Object method (`hash`, `display`, ...)
  # still works through dot notation because an accessor is defined for it.
  class Metadata
    include Enumerable

    # Object methods that must never be shadowed by a metadata key.
    PROTECTED_METHODS = %i[
      class object_id send public_send __send__ __id__ respond_to? respond_to_missing?
      method_missing instance_variable_get instance_variable_set instance_variables
      is_a? kind_of? instance_of? freeze frozen? dup clone itself then tap
      to_h to_s inspect == != equal? eql? each each_pair key? keys values
      fetch dig delete empty? size length to_enum enum_for
    ].to_set.freeze

    def initialize(hash = {})
      @table = {}
      hash.each { |key, value| self[key] = value }
    end

    def [](key)
      @table[key.to_sym]
    end

    def []=(key, value)
      sym = key.to_sym
      @table[sym] = value
      define_accessor(sym) if shadows_object_method?(sym)
      value
    end

    def key?(key) = @table.key?(key.to_sym)

    def keys   = @table.keys
    def values = @table.values
    def size   = @table.size
    alias length size
    def empty? = @table.empty?

    def fetch(key, *default, &block) = @table.fetch(key.to_sym, *default, &block)

    def dig(key, *rest)
      value = self[key]
      rest.empty? || value.nil? ? value : value.dig(*rest)
    end

    def delete(key) = @table.delete(key.to_sym)

    def each(&block)
      return to_enum(:each) unless block

      @table.each(&block)
      self
    end
    alias each_pair each

    def to_h = @table.dup

    def ==(other)
      other.is_a?(Metadata) && to_h == other.to_h
    end

    def inspect = "#<PM::Metadata #{@table.inspect}>"
    alias to_s inspect

    def method_missing(name, *args, &block)
      key = name.to_s

      if key.end_with?('=') && args.size == 1
        self[key.chomp('=')] = args.first
      elsif key.end_with?('?') && args.empty? && boolean_key?(key.chomp('?'))
        self[key.chomp('?')]
      elsif args.empty? && !key.end_with?('?', '!')
        self[key] # nil for unknown keys, matching 1.0.x OpenStruct behaviour
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      key = name.to_s
      return true  if key.end_with?('=')
      return boolean_key?(key.chomp('?')) if key.end_with?('?')
      return false if key.end_with?('!')

      key?(key) || super
    end

    private

    def boolean_key?(key)
      value = self[key]
      value.equal?(true) || value.equal?(false)
    end

    def shadows_object_method?(sym)
      !PROTECTED_METHODS.include?(sym) && Object.public_method_defined?(sym)
    end

    def define_accessor(sym)
      define_singleton_method(sym) { @table[sym] }
    end
  end
end
