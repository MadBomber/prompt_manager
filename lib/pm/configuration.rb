# frozen_string_literal: true

module PM
  class Configuration
    attr_accessor :prompts_dir, :shell, :erb

    def initialize
      reset!
    end

    def reset!
      @prompts_dir = ''
      @shell       = true
      @erb         = true
    end
  end
end
