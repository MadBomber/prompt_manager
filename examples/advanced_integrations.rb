#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'prompt_manager'
  gem 'ruby-openai'
  gem 'tty-spinner'
end

require 'prompt_manager'
require 'openai'
require 'erb'
require 'time'
require 'tty-spinner'

# Configure PromptManager with filesystem adapter
PromptManager::Prompt.storage_adapter = PromptManager::Storage::FileSystemAdapter.config do |config|
  config.prompts_dir = File.join(__dir__, 'prompts_dir')
end.new

# Configure OpenAI client
client = OpenAI::Client.new(
  access_token: ENV['OPENAI_API_KEY']
)

# Get prompt instance and process with LLM
prompt = PromptManager::Prompt.new(
  id: 'advanced_demo',
  erb_flag: true,
  envar_flag: true
)

spinner = TTY::Spinner.new("[:spinner] Waiting for response...")
spinner.auto_spin

response = client.chat(
  parameters: {
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: prompt.to_s }],
    stream: proc do |chunk, _bytesize|
      spinner.stop
      content = chunk.dig("choices", 0, "delta", "content")
      print content if content
      $stdout.flush
    end
  }
)

puts
