# Examples

This section provides comprehensive examples demonstrating various features and use cases of PromptManager.

## Basic Usage

The simplest way to get started with PromptManager:

```ruby
# examples/simple.rb
require 'prompt_manager'

# Configure storage adapter
PromptManager::Prompt.storage_adapter =
  PromptManager::Storage::FileSystemAdapter.config do |config|
    config.prompts_dir = '~/.prompts'
  end.new

# Create and use a prompt
prompt = PromptManager::Prompt.new(id: 'greeting')
prompt.parameters = {
  "[NAME]" => "Alice",
  "[LANGUAGE]" => "English"
}

# Get the processed prompt text
puts prompt.to_s
```

## Advanced Integration with LLM and Streaming

The [advanced_integrations.rb](../examples/advanced_integrations.rb) example demonstrates a complete integration with OpenAI's API, showcasing:

### Features Demonstrated

- **ERB templating** for dynamic content generation
- **Shell integration** for environment variable substitution  
- **OpenAI API integration** with streaming responses
- **Professional UI** with spinner feedback using `tty-spinner`
- **Real-time streaming** of LLM responses

### Code Overview

```ruby
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

# Get prompt instance with advanced features enabled
prompt = PromptManager::Prompt.new(
  id: 'advanced_demo',
  erb_flag: true,    # Enable ERB templating
  envar_flag: true   # Enable environment variable substitution
)

# Show spinner while waiting for response
spinner = TTY::Spinner.new("[:spinner] Waiting for response...")
spinner.auto_spin

# Stream the response from OpenAI
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
```

### Prompt Template

The example uses a sophisticated prompt template ([advanced_demo.txt](../examples/prompts_dir/advanced_demo.txt)) that demonstrates:

```text
# System Analysis and Historical Comparison Report
# Generated with PromptManager - ERB + Shell Integration Demo

```markdown
## Current System Information

**Timestamp**: <%= Time.now.strftime('%A, %B %d, %Y at %I:%M:%S %p %Z') %>
**Analysis Duration**: <%= Time.now - Time.parse('2024-01-01') %> seconds since 2024 began

### Hardware Platform Details
**Architecture**: $HOSTTYPE$MACHTYPE
**Hostname**: $HOSTNAME  
**Operating System**: $OSTYPE
**Shell**: $SHELL (version: $BASH_VERSION)
**User**: $USER
**Home Directory**: $HOME
**Current Path**: $PWD
**Terminal**: $TERM

### Detailed System Profile
<% if RUBY_PLATFORM.include?('darwin') %>
**Platform**: macOS/Darwin System
**Ruby Platform**: <%= RUBY_PLATFORM %>
**Ruby Version**: <%= RUBY_VERSION %>
**Ruby Engine**: <%= RUBY_ENGINE %>
<% elsif RUBY_PLATFORM.include?('linux') %>
**Platform**: Linux System  
**Ruby Platform**: <%= RUBY_PLATFORM %>
**Ruby Version**: <%= RUBY_VERSION %>
**Ruby Engine**: <%= RUBY_ENGINE %>
<% else %>
**Platform**: Other Unix-like System
**Ruby Platform**: <%= RUBY_PLATFORM %>
**Ruby Version**: <%= RUBY_VERSION %>
**Ruby Engine**: <%= RUBY_ENGINE %>
<% end %>

### Performance Context
**Load Average**: <%= `uptime`.strip rescue 'Unable to determine' %>
**Memory Info**: <%= `vm_stat | head -5`.strip rescue 'Unable to determine' if RUBY_PLATFORM.include?('darwin') %>
**Disk Usage**: <%= `df -h / | tail -1`.strip rescue 'Unable to determine' %>

## Analysis Request

You are a technology historian and systems analyst. Please provide a comprehensive comparison between this current system and **the most powerful Apple computer created in the 20th century** (which would be from the 1990s).
```

### Key Benefits

1. **Dynamic Content**: ERB templating allows for real-time system information gathering
2. **Environment Awareness**: Shell integration provides current system context
3. **Professional UX**: Spinner provides visual feedback during API calls  
4. **Real-time Streaming**: Users see responses as they're generated
5. **Comprehensive Analysis**: The prompt generates detailed technical comparisons

## Search Integration

See [using_search_proc.rb](../examples/using_search_proc.rb) for advanced search capabilities:

```ruby
# Configure custom search with ripgrep
PromptManager::Storage::FileSystemAdapter.config do |config|
  config.prompts_dir = '~/.prompts'
  config.search_proc = ->(query) {
    # Use ripgrep for fast searching
    `rg -l "#{query}" #{config.prompts_dir}`.split("\n")
      .map { |path| File.basename(path, '.txt') }
  }
end.new

# Search for prompts containing specific terms
results = PromptManager::Prompt.search("database queries")
puts "Found prompts: #{results.join(', ')}"
```

## Parameter Management

### Basic Parameters

```ruby
prompt = PromptManager::Prompt.new(id: 'template')
prompt.parameters = {
  "[NAME]" => "John",
  "[ROLE]" => "developer",
  "[PROJECT]" => "web application"
}
```

### Parameter History

```ruby
# Parameters support history tracking
prompt.parameters = {
  "[NAME]" => ["Alice", "Bob", "Charlie"]  # Charlie is most recent
}

# Access current value
current_name = prompt.parameters["[NAME]"].last

# Access history
name_history = prompt.parameters["[NAME]"]
```

## Custom Storage Adapters

### Redis Storage Example

```ruby
require 'redis'
require 'json'

class RedisAdapter
  def initialize(redis_client)
    @redis = redis_client
  end

  def get(id:)
    {
      id: id,
      text: @redis.get("prompt:#{id}:text") || "",
      parameters: JSON.parse(@redis.get("prompt:#{id}:params") || '{}')
    }
  end

  def save(id:, text:, parameters:)
    @redis.set("prompt:#{id}:text", text)
    @redis.set("prompt:#{id}:params", parameters.to_json)
  end

  def delete(id:)
    @redis.del("prompt:#{id}:text", "prompt:#{id}:params")
  end

  def search(query)
    # Simple search implementation
    @redis.keys("prompt:*:text").select do |key|
      content = @redis.get(key)
      content&.include?(query)
    end.map { |key| key.split(':')[1] }
  end

  def list
    @redis.keys("prompt:*:text").map { |key| key.split(':')[1] }
  end
end

# Usage
redis = Redis.new
PromptManager::Prompt.storage_adapter = RedisAdapter.new(redis)
```

## Directive Processing

### Custom Directives

```ruby
class CustomDirectiveProcessor < PromptManager::DirectiveProcessor
  def process_directive(directive, prompt)
    case directive
    when /^\/\/model (.+)$/
      set_model($1)
    when /^\/\/temperature (.+)$/
      set_temperature($1.to_f)
    when /^\/\/max_tokens (\d+)$/
      set_max_tokens($1.to_i)
    else
      super  # Handle built-in directives
    end
  end

  private

  def set_model(model)
    @model = model
  end

  def set_temperature(temp)
    @temperature = temp
  end

  def set_max_tokens(tokens)
    @max_tokens = tokens
  end
end

# Usage
prompt = PromptManager::Prompt.new(
  id: 'ai_prompt',
  directives_processor: CustomDirectiveProcessor.new
)
```

## Error Handling

```ruby
begin
  prompt = PromptManager::Prompt.new(id: 'nonexistent')
  result = prompt.to_s
rescue PromptManager::StorageError => e
  puts "Storage error: #{e.message}"
rescue PromptManager::ParameterError => e
  puts "Parameter error: #{e.message}"
rescue PromptManager::ConfigurationError => e
  puts "Configuration error: #{e.message}"
end
```

## Testing Integration

```ruby
# Test helper for prompt testing
def test_prompt(id, params = {})
  prompt = PromptManager::Prompt.new(id: id)
  prompt.parameters = params
  prompt.to_s
end

# Example test
describe "greeting prompt" do
  it "personalizes the greeting" do
    result = test_prompt('greeting', {
      "[NAME]" => "Alice",
      "[TIME]" => "morning"
    })
    
    expect(result).to include("Hello Alice")
    expect(result).to include("Good morning")
  end
end
```

For more examples and advanced usage patterns, see the complete examples in the [examples/](../examples/) directory.