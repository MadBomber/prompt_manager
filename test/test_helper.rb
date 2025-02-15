# frozen_string_literal: true

# frozen_string_literal: true

require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
end

require 'debug_me'
include DebugMe

require 'pathname'

# Add the gem's lib directory to the load path
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# Define test directory and prompts directory
$TEST_DIR     = Pathname.new(__dir__)
$PROMPTS_DIR  = $TEST_DIR.join("../examples/prompts_dir")

require "prompt_manager"
require "minitest/autorun"
require 'minitest/pride'
