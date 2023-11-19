# prompt_manager/lib/prompt_manager.rb
#
# frozen_string_literal: true

require_relative "prompt_manager/version"
require_relative "prompt_manager/storage"
require_relative "prompt_manager/prompt"

module PromptManager
  class Error < StandardError; end
  # TODO: Add some more module specific errors here
end
