# frozen_string_literal: true

# Entry point for `require 'prompt_manager'` (the gem name, which Bundler
# auto-requires). The library lives in the PM namespace; PromptManager is a
# namespace alias only. The 0.x PromptManager::Prompt / Storage API was
# removed in 1.0.0 and is not provided here.
require_relative 'pm'

PromptManager = PM
