# Error Handling

PromptManager provides comprehensive error handling to help you identify and resolve issues during prompt processing.

## Common Exceptions

### `PromptNotFoundError`

Raised when a prompt cannot be located:

```ruby
begin
  prompt = PromptManager::Prompt.new(id: 'nonexistent_prompt')
rescue PromptManager::PromptNotFoundError => e
  puts "Prompt not found: #{e.message}"
  # Handle gracefully - perhaps show available prompts
end
```

### `MissingParametersError`

Raised when required parameters are not provided:

```ruby
begin
  result = prompt.render  # Missing required parameters
rescue PromptManager::MissingParametersError => e
  puts "Missing parameters: #{e.missing_parameters.join(', ')}"
  # Prompt user for missing values
end
```

### `DirectiveProcessingError`

Raised when directive processing fails:

```ruby
begin
  result = prompt.render
rescue PromptManager::DirectiveProcessingError => e
  puts "Directive error: #{e.message}"
  puts "Line: #{e.line_number}" if e.respond_to?(:line_number)
end
```

### `StorageError`

Raised when storage operations fail:

```ruby
begin
  prompt = PromptManager::Prompt.new(id: 'my_prompt')
rescue PromptManager::StorageError => e
  puts "Storage error: #{e.message}"
  # Check file permissions, disk space, etc.
end
```

## Error Recovery Strategies

### Graceful Degradation

```ruby
def safe_render_prompt(prompt_id, params = {})
  begin
    prompt = PromptManager::Prompt.new(id: prompt_id)
    prompt.render(params)
  rescue PromptManager::PromptNotFoundError
    "Default response when prompt is unavailable"
  rescue PromptManager::MissingParametersError => e
    "Please provide: #{e.missing_parameters.join(', ')}"
  rescue => e
    logger.error "Unexpected error rendering prompt: #{e.message}"
    "An error occurred processing your request"
  end
end
```

### Retry Logic

```ruby
def render_with_retry(prompt, params, max_retries: 3)
  retries = 0
  
  begin
    prompt.render(params)
  rescue PromptManager::StorageError => e
    retries += 1
    if retries <= max_retries
      sleep(0.5 * retries)  # Exponential backoff
      retry
    else
      raise e
    end
  end
end
```

## Validation and Prevention

### Parameter Validation

```ruby
def validate_parameters(params, required_params)
  missing = required_params - params.keys
  
  unless missing.empty?
    raise PromptManager::MissingParametersError.new(
      "Missing required parameters: #{missing.join(', ')}",
      missing_parameters: missing
    )
  end
end

# Usage
validate_parameters(user_params, [:customer_name, :order_id])
```

### Pre-flight Checks

```ruby
def preflight_check(prompt_id)
  # Check if prompt exists
  unless PromptManager.storage.exist?(prompt_id)
    raise PromptManager::PromptNotFoundError, "Prompt '#{prompt_id}' not found"
  end
  
  # Check for circular includes
  check_circular_includes(prompt_id)
  
  # Validate syntax
  validate_prompt_syntax(prompt_id)
end
```

## Logging and Debugging

### Enable Debug Logging

```ruby
PromptManager.configure do |config|
  config.debug = true
  config.logger = Logger.new(STDOUT)
end
```

### Custom Error Handlers

```ruby
PromptManager.configure do |config|
  config.error_handler = ->(error, context) {
    # Custom error handling
    ErrorReporter.notify(error, context: context)
    
    # Return fallback response
    case error
    when PromptManager::PromptNotFoundError
      "Prompt temporarily unavailable"
    when PromptManager::MissingParametersError
      "Please check your input parameters"
    else
      "Service temporarily unavailable"
    end
  }
end
```

## Testing Error Conditions

### RSpec Examples

```ruby
describe "Error handling" do
  it "handles missing prompts gracefully" do
    expect {
      PromptManager::Prompt.new(id: 'nonexistent')
    }.to raise_error(PromptManager::PromptNotFoundError)
  end
  
  it "validates required parameters" do
    prompt = PromptManager::Prompt.new(id: 'test_prompt')
    
    expect {
      prompt.render  # No parameters provided
    }.to raise_error(PromptManager::MissingParametersError)
  end
end
```

## Best Practices

1. **Always Handle Exceptions**: Never let PromptManager exceptions bubble up unhandled
2. **Provide Meaningful Fallbacks**: Return sensible defaults when prompts fail
3. **Log Errors**: Capture error details for debugging and monitoring
4. **Validate Early**: Check parameters and conditions before processing
5. **Test Error Paths**: Include error scenarios in your test suite
6. **Monitor in Production**: Set up alerts for prompt processing failures