# frozen_string_literal: true

require 'pathname'

$TEST_DIR     = Pathname.new(__dir__)
$PROMPTS_DIR  = $TEST_DIR + "../examples/prompts_dir"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "prompt_manager"

require "minitest/autorun"
require 'minitest/pride'
