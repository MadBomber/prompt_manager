# frozen_string_literal: true

require 'ostruct'

module PM
  # OpenStruct-based metadata with predicate methods for boolean keys.
  class Metadata < OpenStruct
    def initialize(hash = {})
      super(hash)
      hash.each do |key, value|
        if value.is_a?(TrueClass) || value.is_a?(FalseClass)
          define_singleton_method(:"#{key}?") { send(key) }
        end
      end
    end
  end
end
