# prompt_manager/lib/prompt_manager.rb
#
# frozen_string_literal: true

require 'debug_me'
include DebugMe

require_relative "prompt_manager/version"
require_relative "prompt_manager/storage"
require_relative "prompt_manager/prompt"

module PromptManager
  class Error < StandardError; end
end
