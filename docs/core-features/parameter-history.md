# Parameter History

PromptManager automatically tracks parameter usage history to help you reuse previously entered values and maintain consistency across prompt executions.

## Automatic History Tracking

When you use parameters in your prompts, PromptManager automatically saves the values you provide:

```ruby
prompt = PromptManager::Prompt.new(id: 'customer_email')
result = prompt.render(customer_name: 'John Doe', product: 'Pro Plan')
# These values are automatically saved to history
```

## History File Location

Parameter history is stored in `~/.prompt_manager/parameters_history.yaml` by default.

## Accessing History

Previous parameter values are automatically suggested when you use the same parameter names in subsequent prompts:

```ruby
# First time - you provide values
prompt.render(api_key: 'sk-123', model: 'gpt-4')

# Second time - previous values are available
prompt.render  # Will suggest previously used api_key and model values
```

## History Management

### Viewing History

```ruby
# Access stored parameter values
history = PromptManager.configuration.parameter_history
puts history['api_key']  # Shows previously used API keys
```

### Clearing History

```ruby
# Clear all parameter history
PromptManager.configuration.clear_parameter_history

# Clear specific parameter
PromptManager.configuration.clear_parameter('api_key')
```

## Configuration

Configure history behavior in your application:

```ruby
PromptManager.configure do |config|
  config.save_parameter_history = true  # Enable/disable history (default: true)
  config.parameter_history_file = 'custom_history.yaml'  # Custom file location
  config.max_history_entries = 10  # Limit stored values per parameter
end
```

## Privacy Considerations

Parameter history is stored locally and never transmitted. However, be mindful of sensitive data:

- API keys and tokens are stored in plain text
- Consider clearing history for sensitive parameters
- Use environment variables for truly sensitive data instead of parameter history

## Best Practices

1. **Regular Cleanup**: Periodically clear old parameter values
2. **Sensitive Data**: Don't rely on history for secrets - use environment variables
3. **Team Sharing**: History files are user-specific, not shared across team members
4. **Backup**: Consider backing up important parameter configurations