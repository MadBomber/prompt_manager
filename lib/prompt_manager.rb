# prompt_manager/lib/prompt_manager.rb
#
# frozen_string_literal: true

require 'ostruct'

require_relative "prompt_manager/version"
require_relative "prompt_manager/prompt"
require_relative "prompt_manager/storage"
require_relative "prompt_manager/storage/file_system_adapter"

# The PromptManager module provides functionality for managing, storing,
# retrieving, and parameterizing text prompts used with generative AI systems.
# It supports different storage backends through adapters and offers features
# like parameter substitution, directives processing, and comment handling.
module PromptManager
  # Base error class for all PromptManager-specific errors
  class Error < StandardError; end

  # Error class for storage-related issues
  class StorageError < Error; end

  # Error class for parameter substitution issues
  class ParameterError < Error; end

  # Error class for configuration issues
  class ConfigurationError < Error; end
end
