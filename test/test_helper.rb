# frozen_string_literal: true

require 'debug_me'
include DebugMe

require 'pathname'

require 'simplecov'
SimpleCov.start

# Define test directory and prompts directory
$TEST_DIR     = Pathname.new(__dir__)
$PROMPTS_DIR  = $TEST_DIR.join("../examples/prompts_dir")

# Ensure we are not loading bin/console in a test environment
unless ENV['TEST_ENV'] == 'true'
  $LOAD_PATH.unshift File.expand_path("../lib", __dir__)
  require "prompt_manager"
end

require "minitest/autorun"
require 'minitest/pride'
