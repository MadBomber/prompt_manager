# ERB Integration

PromptManager supports ERB (Embedded Ruby) templating for dynamic content generation.

## Enabling ERB

```ruby
prompt = PromptManager::Prompt.new(
  id: 'dynamic_prompt',
  erb_flag: true
)
```

## Basic Usage

```text title="dynamic_prompt.txt"
Current date: <%= Date.today.strftime('%B %d, %Y') %>

<% if '[PRIORITY]' == 'high' %>
🚨 URGENT: This requires immediate attention!
<% else %>
📋 Standard processing request.
<% end %>

Generated at: <%= Time.now %>
```

## Advanced Examples

### System Information Template

```text
**Timestamp**: <%= Time.now.strftime('%A, %B %d, %Y at %I:%M:%S %p %Z') %>
**Analysis Duration**: <%= Time.now - Time.parse('2024-01-01') %> seconds since 2024 began

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

**Performance Context**: <%= `uptime`.strip rescue 'Unable to determine' %>
```

### Complete Integration Example

See the complete [advanced_integrations.rb](../../examples/advanced_integrations.rb) example that demonstrates:

- ERB templating with system information
- Dynamic timestamp generation
- Platform-specific content rendering
- Integration with OpenAI API streaming
- Professional UI with `tty-spinner`

This example shows how to create sophisticated prompts that adapt to your system environment and generate technical analysis reports.

For more comprehensive ERB examples, see the [Examples documentation](../examples.md).