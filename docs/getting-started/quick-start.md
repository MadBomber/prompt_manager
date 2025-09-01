# Quick Start

This guide will get you up and running with PromptManager in just a few minutes.

## 1. Install PromptManager

```bash
gem install prompt_manager
```

## 2. Set Up Your First Prompt

Create a directory for your prompts and your first prompt file:

```bash
mkdir ~/.prompts
```

Create your first prompt file:

=== "~/.prompts/greeting.txt"

    ```text
    # Description: A friendly greeting prompt
    # Keywords: NAME, LANGUAGE
    
    Hello [NAME]! 
    
    I'm here to help you today. Please let me know how I can assist you,
    and I'll respond in [LANGUAGE].
    
    What would you like to know about?
    ```

=== "~/.prompts/greeting.json"

    ```json
    {
      "[NAME]": ["Alice", "Bob", "Charlie"],
      "[LANGUAGE]": ["English", "Spanish", "French"]
    }
    ```

## 3. Basic Usage

Create a simple Ruby script to use your prompt:

```ruby title="quick_example.rb"
#!/usr/bin/env ruby

require 'prompt_manager'

# Configure the FileSystem storage adapter
PromptManager::Prompt.storage_adapter = 
  PromptManager::Storage::FileSystemAdapter.config do |config|
    config.prompts_dir = File.expand_path('~/.prompts')
  end.new

# Load your prompt
prompt = PromptManager::Prompt.new(id: 'greeting')

# Set parameter values
prompt.parameters = {
  "[NAME]" => "Alice",
  "[LANGUAGE]" => "English"
}

# Generate the final prompt text
puts "=== Generated Prompt ==="
puts prompt.to_s

# Save any parameter changes
prompt.save
```

Run it:

```bash
ruby quick_example.rb
```

Expected output:
```
=== Generated Prompt ===
Hello Alice! 

I'm here to help you today. Please let me know how I can assist you,
and I'll respond in English.

What would you like to know about?
```

## 4. Understanding the Workflow

The basic PromptManager workflow involves:

```mermaid
graph LR
    A[Create Prompt File] --> B[Configure Storage]
    B --> C[Load Prompt]
    C --> D[Set Parameters]
    D --> E[Generate Text]
    E --> F[Save Changes]
```

### Step by Step:

1. **Create Prompt File**: Write your template with `[KEYWORDS]`
2. **Configure Storage**: Choose FileSystem or ActiveRecord adapter
3. **Load Prompt**: Create a Prompt instance with an ID
4. **Set Parameters**: Provide values for your keywords
5. **Generate Text**: Call `to_s` to get the final prompt
6. **Save Changes**: Persist parameter updates

## 5. Advanced Quick Start

Here's a more advanced example showing multiple features:

```ruby title="advanced_example.rb"
require 'prompt_manager'

# Configure storage
PromptManager::Prompt.storage_adapter = 
  PromptManager::Storage::FileSystemAdapter.config do |config|
    config.prompts_dir = File.expand_path('~/.prompts')
  end.new

# Create a prompt with directives and ERB
prompt = PromptManager::Prompt.new(
  id: 'advanced_greeting',
  erb_flag: true,
  envar_flag: true
)

# Set parameters
prompt.parameters = {
  "[USER_NAME]" => "Alice",
  "[TASK_TYPE]" => "translation",
  "[URGENCY]" => "high"
}

# Display available keywords
puts "Available keywords: #{prompt.keywords.join(', ')}"

# Generate and display the result
puts "\n=== Final Prompt ==="
puts prompt.to_s

# Save changes
prompt.save
puts "\nPrompt saved successfully!"
```

=== "~/.prompts/advanced_greeting.txt"

    ```text
    # Advanced greeting with directives and ERB
    //include common/header.txt
    
    Dear [USER_NAME],
    
    <% if '[URGENCY]' == 'high' %>
    🚨 URGENT: This [TASK_TYPE] request requires immediate attention.
    <% else %>
    📋 Standard [TASK_TYPE] request for processing.
    <% end %>
    
    Current system time: <%= Time.now.strftime('%Y-%m-%d %H:%M:%S') %>
    Working directory: <%= Dir.pwd %>
    
    __END__
    This section is ignored - useful for notes and documentation.
    ```

## 6. Next Steps

Now that you have PromptManager working, explore these areas:

### Learn Core Features
- [Parameterized Prompts](../core-features/parameterized-prompts.md) - Master keyword substitution
- [Directive Processing](../core-features/directive-processing.md) - Include files and process commands
- [ERB Integration](../core-features/erb-integration.md) - Dynamic templating

### Storage Options  
- [FileSystem Adapter](../storage/filesystem-adapter.md) - File-based storage
- [ActiveRecord Adapter](../storage/activerecord-adapter.md) - Database storage
- [Custom Adapters](../storage/custom-adapters.md) - Build your own

### Advanced Usage
- [Custom Keywords](../advanced/custom-keywords.md) - Define your own keyword patterns
- [Search Integration](../advanced/search-integration.md) - Find prompts quickly
- [Performance Tips](../advanced/performance.md) - Optimize for large collections

### Real Examples
- [Basic Examples](../examples/basic.md) - Simple use cases
- [Advanced Examples](../examples/advanced.md) - Complex scenarios
- [Real World Cases](../examples/real-world.md) - Production examples

## Common Patterns

Here are some common patterns you'll use frequently:

### Parameter History
```ruby
# Access parameter history (since v0.3.0)
prompt.parameters["[NAME]"]  # Returns ["Alice", "Bob", "Charlie"] 
latest_name = prompt.parameters["[NAME]"].last  # "Charlie"
```

### Error Handling
```ruby
begin
  prompt = PromptManager::Prompt.new(id: 'missing')
rescue PromptManager::StorageError => e
  puts "Storage error: #{e.message}"
rescue PromptManager::ParameterError => e
  puts "Parameter error: #{e.message}"
end
```

### Search and Discovery
```ruby
# List all available prompts
prompts = PromptManager::Prompt.list
puts "Available prompts: #{prompts.join(', ')}"

# Search for prompts (requires search_proc configuration)
results = PromptManager::Prompt.search('greeting')
```

## Troubleshooting

### File Not Found
If you get "file not found" errors, check:

1. **Prompt directory exists**: `ls ~/.prompts`
2. **File has correct extension**: Should be `.txt` by default
3. **Prompt ID matches filename**: `greeting` looks for `greeting.txt`

### Parameter Errors
If parameters aren't substituting:

1. **Check keyword format**: Must be `[UPPERCASE]` by default
2. **Verify parameter keys match**: Case-sensitive matching
3. **Ensure parameters are set**: Call `prompt.parameters = {...}`

### Permission Issues
If you can't write to the prompts directory:

```bash
chmod 755 ~/.prompts
chmod 644 ~/.prompts/*.txt
chmod 644 ~/.prompts/*.json
```

Need help? Check our [testing guide](../development/testing.md) or [open an issue](https://github.com/MadBomber/prompt_manager/issues).