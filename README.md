# PromptManager

> [!CAUTION]
> ## ⚠️ Breaking Changes are Coming ⚠️
> See [Roadmap](#roadmap) for details about upcoming changes.
<br />
<div align="center">
  <table>
    <tr>
      <td width="40%" align="center" valign="top">
        <a href="https://madbomber.github.io/blog/" target="_blank">
          <img src="prompt_manager_logo.png" alt="PromptManager - The Enchanted Librarian of AI Prompts" width="800">
        </a>
        <br /><br />
        [Comprehensive Documentation Website](https://madbomber.github.io/prompt_manager/)
      </td>
      <td width="60%" align="left" valign="top">
        Like an enchanted librarian organizing floating books of knowledge, PromptManager helps you masterfully orchestrate and organize your AI prompts through wisdom and experience. Each prompt becomes a living entity that can be categorized, parameterized, and interconnected with golden threads of relationships.
        <br/><br/>
        <h3>Key Features</h3>
        <ul>
            <li><strong>📚 <a href="#storage-adapters">Multiple Storage Adapters</a></strong>
            <li><strong>🔧 <a href="#parameterized-prompts">Parameterized Prompts</a></strong>
            <li><strong>📋 <a href="#directive-processing">Directive Processing</a></strong>
            <li><strong>🎨 <a href="#erb-and-shell-integration">ERB Integration</a></strong>
            <li><strong>🌍 <a href="#erb-and-shell-integration">Shell Integration</a></strong>
            <li><strong>📖 <a href="#comments-and-documentation">Inline Documentation</a></strong>
            <li><strong>📊 <a href="#parameter-history">Parameter History</a></strong>
            <li><strong>⚡ <a href="#error-handling">Error Handling</a></strong>
            <li><strong>🔌 <a href="#extensible-architecture">Extensible Architecture</a></strong>
        </ul>
      </td>
    </tr>
  </table>
</div>

## Table of Contents

* [Installation](#installation)
* [Quick Start](#quick-start)
* [Core Features](#core-features)
  * [Parameterized Prompts](#parameterized-prompts)
    * [Keyword Syntax](#keyword-syntax)
    * [Custom Patterns](#custom-patterns)
    * [Working with Parameters](#working-with-parameters)
  * [Directive Processing](#directive-processing)
    * [Built\-in Directives](#built-in-directives)
    * [Directive Syntax](#directive-syntax)
    * [Custom Directive Processors](#custom-directive-processors)
  * [ERB and Shell Integration](#erb-and-shell-integration)
    * [ERB Templates](#erb-templates)
    * [Environment Variables](#environment-variables)
  * [Comments and Documentation](#comments-and-documentation)
    * [Line Comments](#line-comments)
    * [Block Comments](#block-comments)
    * [Blank Lines](#blank-lines)
  * [Parameter History](#parameter-history)
  * [Error Handling](#error-handling)
* [Storage Adapters](#storage-adapters)
  * [FileSystemAdapter](#filesystemadapter)
    * [Configuration](#configuration)
    * [File Structure](#file-structure)
    * [Custom Search](#custom-search)
    * [Extra Methods](#extra-methods)
  * [ActiveRecordAdapter](#activerecordadapter)
    * [Configuration](#configuration-1)
    * [Database Setup](#database-setup)
  * [Custom Adapters](#custom-adapters)
* [Configuration](#configuration-2)
  * [Initialization Options](#initialization-options)
  * [Global Configuration](#global-configuration)
* [Advanced Usage](#advanced-usage)
  * [Custom Keyword Patterns](#custom-keyword-patterns)
  * [Dynamic Directives](#dynamic-directives)
  * [Search Capabilities](#search-capabilities)
* [Examples](#examples)
  * [Basic Usage](#basic-usage)
  * [With Search](#with-search)
  * [Custom Storage](#custom-storage)
* [Extensible Architecture](#extensible-architecture)
  * [Extension Points](#extension-points)
  * [Potential Extensions](#potential-extensions)
* [Roadmap](#roadmap)
  * [v0\.9\.0 \- Modern Prompt Format (Breaking Changes)](#v090---modern-prompt-format-breaking-changes)
  * [v1\.0\.0 \- Stability Release](#v100---stability-release)
  * [Future Enhancements](#future-enhancements)
* [Development](#development)
* [Contributing](#contributing)
* [License](#license)

## Installation

Install the gem and add to the application's Gemfile by executing:

    bundle add prompt_manager

If bundler is not being used to manage dependencies, install the gem by executing:

    gem install prompt_manager

## Quick Start

```ruby
require 'prompt_manager'

# Configure storage adapter
PromptManager::Prompt.storage_adapter =
  PromptManager::Storage::FileSystemAdapter.config do |config|
    config.prompts_dir = '~/.prompts'
  end.new

# Load and use a prompt
prompt = PromptManager::Prompt.new(id: 'greeting')
prompt.parameters = {
  "[NAME]" => "Alice",
  "[LANGUAGE]" => "English"
}

# Get the processed prompt text
result = prompt.to_s
```

## Core Features

### Parameterized Prompts

The heart of PromptManager is its ability to manage parameterized prompts - text templates with embedded keywords that can be replaced with dynamic values.

#### Keyword Syntax

By default, keywords are enclosed in square brackets: `[KEYWORD]`, `[MULTIPLE WORDS]`, or `[WITH_UNDERSCORES]`.

```ruby
prompt_text = "Hello [NAME], please translate this to [LANGUAGE]"
```

#### Custom Patterns

You can customize the keyword pattern to match your preferences:

```ruby
# Use {{mustache}} style
PromptManager::Prompt.parameter_regex = /(\{\{[A-Za-z_]+\}\})/

# Use :colon style
PromptManager::Prompt.parameter_regex = /(:[a-z_]+)/
```

The regex must include capturing parentheses `()` to extract the keyword.

#### Working with Parameters

```ruby
prompt = PromptManager::Prompt.new(id: 'example')

# Get all keywords found in the prompt
keywords = prompt.keywords  #=> ["[NAME]", "[LANGUAGE]"]

# Set parameter values
prompt.parameters = {
  "[NAME]" => "Alice",
  "[LANGUAGE]" => "French"
}

# Get processed text with substitutions
final_text = prompt.to_s

# Save changes
prompt.save
```

### Directive Processing

Directives are special line oriented instructions in your prompts that begin with `//` starting in column 1. They're inspired by IBM JCL and provide powerful prompt composition capabilities.  A character string that begins with `//` but is not at the very beginning of the line will NOT be processed as a directive.

#### Built-in Directives

**`//include` (alias: `//import`)** - Include content from other files:

```text
//include common/header.txt
//import [TEMPLATE_NAME].txt

Main prompt content here...
```

Features:
- Loop protection prevents circular includes
- Supports keyword substitution in file paths
- Processes included files recursively

#### Directive Syntax

```text
//directive_name [PARAM1] [PARAM2] options

# Dynamic directives using keywords
//[COMMAND] [OPTIONS]
```

#### Custom Directive Processors

You can create custom directive processors:

```ruby
class MyDirectiveProcessor < PromptManager::DirectiveProcessor
  def process_directive(directive, prompt)
    case directive
    when /^\/\/model (.+)$/
      set_model($1)
    when /^\/\/temperature (.+)$/
      set_temperature($1.to_f)
    else
      super
    end
  end
end

prompt = PromptManager::Prompt.new(
  id: 'example',
  directives_processor: MyDirectiveProcessor.new
)
```

### ERB and Shell Integration

#### ERB Templates

Enable ERB processing for dynamic content generation:

```ruby
prompt = PromptManager::Prompt.new(
  id: 'dynamic',
  erb_flag: true
)
```

Example prompt with ERB:

```text
Today's date is <%= Date.today %>
<% 5.times do |i| %>
  Item <%= i + 1 %>
<% end %>
```

#### Environment Variables

Enable automatic environment variable substitution:

```ruby
prompt = PromptManager::Prompt.new(
  id: 'with_env',
  envar_flag: true
)
```

Environment variables are automatically replaced in the prompt text.

### Comments and Documentation

PromptManager supports comprehensive inline documentation:

#### Line Comments

Lines beginning with `#` are treated as comments:

```text
# This is a comment
# Description: This prompt does something useful

Actual prompt text here...
```

#### Block Comments

Everything after `__END__` is ignored:

```text
Main prompt content...

__END__
Development notes:
- This section is completely ignored
- Great for documentation
- TODO items
```

#### Blank Lines

Blank lines are automatically removed from the final output.

### Parameter History

PromptManager maintains a history of parameter values (since v0.3.0):

```ruby
# Parameters are stored as arrays
prompt.parameters = {
  "[NAME]" => ["Alice", "Bob", "Charlie"]  # Charlie is most recent
}

# The last value is always the most recent
current_name = prompt.parameters["[NAME]"].last

# Useful for:
# - Implementing value history in UIs
# - Providing dropdown selections
# - Tracking parameter usage over time
```

### Error Handling

PromptManager provides specific error classes for better debugging:

```ruby
begin
  prompt = PromptManager::Prompt.new(id: 'missing')
rescue PromptManager::StorageError => e
  # Handle storage-related errors
  puts "Storage error: #{e.message}"
rescue PromptManager::ParameterError => e
  # Handle parameter substitution errors
  puts "Parameter error: #{e.message}"
rescue PromptManager::ConfigurationError => e
  # Handle configuration errors
  puts "Configuration error: #{e.message}"
end
```

## Storage Adapters

Storage adapters provide the persistence layer for prompts. PromptManager includes two built-in adapters and supports custom implementations.

### FileSystemAdapter

Stores prompts as text files in a directory structure.

#### Configuration

```ruby
PromptManager::Storage::FileSystemAdapter.config do |config|
  config.prompts_dir       = "~/.prompts"      # Required
  config.search_proc       = nil               # Optional custom search
  config.prompt_extension  = '.txt'            # Default
  config.params_extension  = '.json'           # Default
end
```

#### File Structure

```
~/.prompts/
├── greeting.txt        # Prompt text
├── greeting.json       # Parameters
├── email/
│   ├── welcome.txt
│   └── welcome.json
```

#### Custom Search

Integrate with external search tools:

```ruby
config.search_proc = ->(query) {
  # Use ripgrep for fast searching
  `rg -l "#{query}" #{config.prompts_dir}`.split("\n")
}
```

#### Extra Methods

- `list` - Returns array of all prompt IDs
- `path(id)` - Returns Pathname to prompt file

### ActiveRecordAdapter

Stores prompts in a database using ActiveRecord.

#### Configuration

```ruby
PromptManager::Storage::ActiveRecordAdapter.config do |config|
  config.model              = PromptModel      # Your AR model
  config.id_column          = :prompt_id       # Column for ID
  config.text_column        = :content         # Column for text
  config.parameters_column  = :params          # Column for parameters
end
```

#### Database Setup

```ruby
class CreatePrompts < ActiveRecord::Migration[7.0]
  def change
    create_table :prompts do |t|
      t.string :prompt_id, null: false, index: { unique: true }
      t.text :content
      t.json :params
      t.timestamps
    end
  end
end
```

### Custom Adapters

Create your own storage adapter:

```ruby
class RedisAdapter
  def initialize(redis_client)
    @redis = redis_client
  end

  def get(id)
    prompt_text = @redis.get("prompt:#{id}:text")
    parameters = JSON.parse(@redis.get("prompt:#{id}:params") || '{}')
    [prompt_text, parameters]
  end

  def save(id, text, parameters)
    @redis.set("prompt:#{id}:text", text)
    @redis.set("prompt:#{id}:params", parameters.to_json)
  end

  def delete(id)
    @redis.del("prompt:#{id}:text", "prompt:#{id}:params")
  end

  def list
    @redis.keys("prompt:*:text").map { |k| k.split(':')[1] }
  end
end
```

## Configuration

### Initialization Options

When creating a prompt instance:

```ruby
prompt = PromptManager::Prompt.new(
  id: 'example',
  context: ['additional', 'context'],
  directives_processor: CustomProcessor.new,
  external_binding: binding,
  erb_flag: true,
  envar_flag: true
)
```

Options:
- `id` - Unique identifier for the prompt
- `context` - Additional context array
- `directives_processor` - Custom directive processor
- `external_binding` - Ruby binding for ERB
- `erb_flag` - Enable ERB processing
- `envar_flag` - Enable environment variable substitution

### Global Configuration

Set the storage adapter globally:

```ruby
PromptManager::Prompt.storage_adapter = adapter_instance
```

## Advanced Usage

### Custom Keyword Patterns

Examples of different keyword patterns:

```ruby
# Handlebars style: {{name}}
PromptManager::Prompt.parameter_regex = /(\{\{[a-z_]+\}\})/

# Colon prefix: :name
PromptManager::Prompt.parameter_regex = /(:[a-z_]+)/

# Dollar sign: $NAME
PromptManager::Prompt.parameter_regex = /(\$[A-Z_]+)/

# Percentage: %name%
PromptManager::Prompt.parameter_regex = /(%[a-z_]+%)/
```

### Dynamic Directives

Create directives that change based on parameters:

```text
# Set directive name via parameter
//[DIRECTIVE_TYPE] [OPTIONS]

# Conditional directives
//include templates/[TEMPLATE_TYPE].txt
```

### Search Capabilities

Implement powerful search across prompts:

```ruby
# With FileSystemAdapter
adapter.search_proc = ->(query) {
  # Custom search implementation
  results = []
  Dir.glob("#{prompts_dir}/**/*.txt").each do |file|
    content = File.read(file)
    if content.include?(query)
      results << File.basename(file, '.txt')
    end
  end
  results
}

# With ActiveRecordAdapter
PromptModel.where("content LIKE ?", "%#{query}%").pluck(:prompt_id)
```

## Examples

### Basic Usage

```ruby
# examples/simple.rb
require 'prompt_manager'

# Setup
PromptManager::Prompt.storage_adapter =
  PromptManager::Storage::FileSystemAdapter.config do |c|
    c.prompts_dir = '~/.prompts'
  end.new

# Create and use a prompt
prompt = PromptManager::Prompt.new(id: 'story')
prompt.parameters = {
  "[GENRE]" => "fantasy",
  "[CHARACTER]" => "wizard"
}

puts prompt.to_s
```

### Advanced Integration with LLM and Streaming

See [examples/advanced_integrations.rb](examples/advanced_integrations.rb) for a complete example that demonstrates:

- **ERB templating** for dynamic content generation
- **Shell integration** for environment variable substitution
- **OpenAI API integration** with streaming responses
- **Professional UI** with spinner feedback using `tty-spinner`

This example shows how to create sophisticated AI prompts that adapt to your system environment and stream responses in real-time.

### With Search

See [examples/using_search_proc.rb](examples/using_search_proc.rb) for advanced search integration.

### Custom Storage

```ruby
# examples/redis_storage.rb
class RedisStorage
  # ... implementation
end

PromptManager::Prompt.storage_adapter = RedisStorage.new(Redis.new)
```

## Extensible Architecture

PromptManager is designed to be extended:

### Extension Points

1. **Storage Adapters** - Implement your own persistence layer
2. **Directive Processors** - Add custom directives
3. **Search Processors** - Integrate external search tools
4. **Serializers** - Support different parameter formats

### Potential Extensions

- **CloudStorageAdapter** - S3, Google Cloud Storage
- **RedisAdapter** - For caching and fast access
- **ApiAdapter** - REST API backend
- **GraphQLAdapter** - GraphQL endpoint storage
- **GitAdapter** - Version controlled prompts

## Roadmap

### v0.9.0 - Modern Prompt Format (Breaking Changes)
- **Markdown Support**: Full `.md` file support with YAML front matter
- **Modern Parameter Syntax**: Support for `{{keyword}}` format
- **Enhanced API**: New `set_parameter()` and `get_parameter()` methods
- **Parameter Validation**: Built-in validation based on specifications
- **HTML Comments**: Support for `<!-- comments -->`
- **Migration Tools**: Automated conversion utilities

### v1.0.0 - Stability Release
- Performance optimizations
- Complete documentation
- Production hardening

### Future Enhancements
- Additional storage adapters
- Enhanced directive system with plugins
- Prompt versioning and inheritance
- Performance optimizations for large collections

## Development

Looking for feedback and contributors to enhance the capability of prompt_manager.

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/MadBomber/prompt_manager](https://github.com/MadBomber/prompt_manager).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
