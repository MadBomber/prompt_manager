#!/usr/bin/env ruby
require 'minitest/autorun'
require_relative '../lib/prompt_manager/prompt'

class TestPromptFeatures < Minitest::Test
  def setup
    @original_env = ENV.to_hash
  end

  def teardown
    ENV.replace(@original_env)
  end

  def test_env_variable_replacement
    ENV['GREETING'] = 'Hello'
    prompt_text = 'Say $GREETING to world!'
    prompt = PromptManager::Prompt.new(prompt_text)
    result = prompt.process
    assert_equal 'Say Hello to world!', result
  end

  def test_erb_processing
    prompt_text = '2+2 is <%= 2+2 %>'
    prompt = PromptManager::Prompt.new(prompt_text)
    result = prompt.process
    assert_equal '2+2 is 4', result
  end

  def test_combined_features
    ENV['NAME'] = 'Alice'
    prompt_text = 'Hi, $NAME! Today, 3*3 equals <%= 3*3 %>.'
    prompt = PromptManager::Prompt.new(prompt_text)
    result = prompt.process
    assert_equal 'Hi, Alice! Today, 3*3 equals 9.', result
  end
end
