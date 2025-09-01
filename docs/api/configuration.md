# Configuration API Reference

PromptManager provides comprehensive configuration options to customize behavior for your specific needs.

## Basic Configuration

```ruby
PromptManager.configure do |config|
  # Storage adapter (default: FileSystemAdapter)
  config.storage = PromptManager::Storage::FileSystemAdapter.new
  
  # Default prompts directory (default: ~/prompts_dir/)
  config.prompts_dir = '/path/to/your/prompts'
  
  # Enable debug logging (default: false)
  config.debug = true
  
  # Custom logger (default: Rails.logger or Logger.new(STDOUT))
  config.logger = Logger.new('/var/log/prompt_manager.log')
end
```

## Configuration Options

### Core Settings

#### `storage`
**Type:** `PromptManager::Storage::Base`
**Default:** `FileSystemAdapter.new`

The storage adapter to use for reading and writing prompts.

```ruby
# FileSystem storage
config.storage = PromptManager::Storage::FileSystemAdapter.new(
  prompts_dir: '/custom/prompts/path'
)

# ActiveRecord storage  
config.storage = PromptManager::Storage::ActiveRecordAdapter.new(
  model_class: Prompt
)

# Custom storage
config.storage = MyCustomAdapter.new
```

#### `prompts_dir`
**Type:** `String` or `Array<String>`
**Default:** `File.join(Dir.home, 'prompts_dir')`

Directory path(s) to search for prompt files when using FileSystemAdapter.

```ruby
# Single directory
config.prompts_dir = '/app/prompts'

# Multiple directories (search in order)
config.prompts_dir = [
  '/app/prompts',
  '/shared/prompts', 
  '/system/default_prompts'
]
```

#### `debug`
**Type:** `Boolean`
**Default:** `false`

Enable debug logging for troubleshooting.

```ruby
config.debug = true
```

#### `logger`
**Type:** `Logger`
**Default:** `Rails.logger` or `Logger.new(STDOUT)`

Custom logger instance for PromptManager output.

```ruby
config.logger = Logger.new('/var/log/prompt_manager.log')
config.logger.level = Logger::DEBUG
```

### Parameter Processing

#### `save_parameter_history`
**Type:** `Boolean`
**Default:** `true`

Whether to save parameter values for reuse in future prompt renderings.

```ruby
config.save_parameter_history = false
```

#### `parameter_history_file`
**Type:** `String`
**Default:** `~/.prompt_manager/parameters_history.yaml`

File path for storing parameter history.

```ruby
config.parameter_history_file = '/app/data/prompt_history.yaml'
```

#### `max_history_entries`
**Type:** `Integer`
**Default:** `10`

Maximum number of historical values to store per parameter.

```ruby
config.max_history_entries = 5
```

### ERB Processing

#### `erb_timeout`
**Type:** `Numeric`
**Default:** `30` (seconds)

Timeout for ERB template processing to prevent infinite loops.

```ruby
config.erb_timeout = 60  # 1 minute
```

#### `erb_safe_level`
**Type:** `Integer`
**Default:** `0`

Ruby safe level for ERB evaluation (0-4, higher = more restrictive).

```ruby
config.erb_safe_level = 1  # Slightly more restrictive
```

### Directive Processing

#### `max_include_depth`
**Type:** `Integer`
**Default:** `10`

Maximum depth for nested `//include` directives to prevent circular includes.

```ruby
config.max_include_depth = 5
```

#### `directive_timeout`
**Type:** `Numeric`
**Default:** `30` (seconds)

Timeout for directive processing.

```ruby
config.directive_timeout = 60
```

### Caching

#### `cache_prompts`
**Type:** `Boolean`
**Default:** `false`

Enable in-memory caching of prompt content.

```ruby
config.cache_prompts = true
```

#### `cache_ttl`
**Type:** `Numeric`
**Default:** `300` (5 minutes)

Time-to-live for cached prompt content in seconds.

```ruby
config.cache_ttl = 600  # 10 minutes
```

#### `cache_store`
**Type:** `ActiveSupport::Cache::Store`
**Default:** `ActiveSupport::Cache::MemoryStore.new`

Custom cache store for prompt content.

```ruby
config.cache_store = ActiveSupport::Cache::RedisStore.new(
  url: ENV['REDIS_URL']
)
```

### Error Handling

#### `error_handler`
**Type:** `Proc`
**Default:** `nil`

Custom error handler for prompt processing errors.

```ruby
config.error_handler = ->(error, context) {
  Rails.logger.error "Prompt error: #{error.message}"
  ErrorReporter.notify(error, context: context)
  
  # Return fallback content
  "Service temporarily unavailable"
}
```

#### `raise_on_missing_prompts`
**Type:** `Boolean`
**Default:** `true`

Whether to raise exceptions for missing prompts or return nil.

```ruby
config.raise_on_missing_prompts = false
```

#### `raise_on_missing_parameters`
**Type:** `Boolean`
**Default:** `true`

Whether to raise exceptions for missing parameters or substitute with placeholders.

```ruby
config.raise_on_missing_parameters = false
```

## Environment-based Configuration

### Rails Configuration

```ruby
# config/environments/development.rb
Rails.application.configure do
  config.prompt_manager.debug = true
  config.prompt_manager.prompts_dir = Rails.root.join('app', 'prompts')
  config.prompt_manager.save_parameter_history = true
end

# config/environments/production.rb
Rails.application.configure do
  config.prompt_manager.debug = false
  config.prompt_manager.cache_prompts = true
  config.prompt_manager.cache_ttl = 3600  # 1 hour
  
  config.prompt_manager.error_handler = ->(error, context) {
    Rollbar.error(error, context)
    "Service temporarily unavailable"
  }
end
```

### Environment Variables

PromptManager respects these environment variables:

```bash
# Storage configuration
PROMPT_MANAGER_PROMPTS_DIR="/app/prompts"
PROMPT_MANAGER_DEBUG="true"

# Cache configuration  
PROMPT_MANAGER_CACHE_PROMPTS="true"
PROMPT_MANAGER_CACHE_TTL="600"

# Database URL for ActiveRecord adapter
DATABASE_URL="postgres://user:pass@localhost/prompts_db"
```

## Configuration Validation

Validate your configuration:

```ruby
PromptManager.configure do |config|
  config.storage = MyAdapter.new
  config.debug = true
end

# Validate configuration
begin
  PromptManager.validate_configuration!
  puts "Configuration valid"
rescue PromptManager::ConfigurationError => e
  puts "Configuration error: #{e.message}"
end
```

## Runtime Configuration

Access current configuration:

```ruby
# Get current storage adapter
storage = PromptManager.configuration.storage

# Check debug mode
if PromptManager.configuration.debug
  puts "Debug mode enabled"
end

# Access logger
PromptManager.configuration.logger.info("Processing prompt...")
```

## Configuration Best Practices

### Development
```ruby
PromptManager.configure do |config|
  config.debug = true
  config.prompts_dir = './prompts'
  config.save_parameter_history = true
  config.cache_prompts = false  # Always reload for development
end
```

### Production
```ruby
PromptManager.configure do |config|
  config.debug = false
  config.cache_prompts = true
  config.cache_ttl = 3600
  
  config.error_handler = ->(error, context) {
    ErrorService.notify(error, context)
    "Service temporarily unavailable"
  }
  
  # Use database storage for high availability
  config.storage = PromptManager::Storage::ActiveRecordAdapter.new
end
```

### Testing
```ruby
# spec/spec_helper.rb
RSpec.configure do |config|
  config.before(:each) do
    PromptManager.configure do |config|
      config.prompts_dir = Rails.root.join('spec', 'fixtures', 'prompts')
      config.save_parameter_history = false
      config.cache_prompts = false
      config.raise_on_missing_prompts = true
    end
  end
end
```